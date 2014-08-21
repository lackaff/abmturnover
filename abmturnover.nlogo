;; Identify global variables -- these are model-level (rather than agent-level)
globals [ iteration avg_age stddev_age mean_mtd stddev_mtd mean_satisfaction
  stddev_satisfaction mean_opportunity stddev_opportunity total_attrition attrition_ages mean_attrition_age stddev_attrition_age ]

breed [ nodes node ]
breed [ coaches coach ]
breed [ links link ]

;; Identify variables that each agent will possess
nodes-own [ seniority age mtd mtd_history mtd_decay coached_this_t opportunity coachedby satisfaction ]
coaches-own [ coach_quality coachedby num_coached ]

to setup
  ca
  set-default-shape nodes "face happy"
  set-default-shape coaches "person"

  ;; Create all agents
  create-custom-nodes number-of-nodes
  [
    set color blue
    set size 1
    ;; Form a circle.
    __layout-circle nodes max-pxcor - 2
  ]

  ;; Setup initial values for all agents
  ask nodes [

    ifelse (who-of self <= number-of-coaches) [
      set breed coaches
      set size 3
      set coach_quality random-normal avg_coach_quality 2
      if (coach_quality > 10) [ set coach_quality 10 ]
      if (coach_quality < 1) [ set coach_quality 1 ]
      set color scale-color red coach_quality 1 10
    ]

    [ set age random-normal age 6
    if (age >= 48) [ set seniority 8 set size 6 ]
    if (age < 48)  [ set seniority 6 set size 5 ]
    if (age < 42)  [ set seniority 4 set size 5 ]
    if (age < 36)  [ set seniority 2 set size 4 ]
    if (age < 30)  [ set seniority 0 set size 4 ]
    if (age < 24)  [ set seniority 0 set size 3 ]
    if (age < 18)  [ set seniority 2 set size 2 ]
    if (age < 12)  [ set seniority 4 set size 1 ]
    if (age < 6) [ set seniority 6 set size 1]

    set mtd starting-mtd
    set mtd_decay random-normal avg_mtd_decay 1
 ;;   set mtd_decay avg_mtd_decay
    set opportunity random 100
    set coachedby "none" ]

    form-coach-link ;; Make all agents choose a coach
  ]

  set iteration 0
  set attrition_ages [] ;; Make this variable a list
end

;; This is what happens at each iteration:
to go

  ;; These are node-specific commands:
  ask nodes [
    form-coach-link
    calculate-coached-this-t
    calculate-mtd
    calculate-opportunity
    calculate-satisfaction
    calculate-leave
    calculate-seniority
  ]

  ;; these are coach-specific commands
  ask coaches [
    ifelse show_coached? [ set label num_coached ] [set label "" ]
  ]

  ;; These are global or general procedures:
  set iteration iteration + 1

  set mean_satisfaction ( mean values-from nodes [satisfaction] )
  set stddev_satisfaction ( standard-deviation values-from nodes [satisfaction] )
  set mean_mtd ( mean values-from nodes [ mtd ] )
  set stddev_mtd ( standard-deviation values-from nodes [mtd] )
  set mean_opportunity ( mean values-from nodes [ opportunity ] )
  set stddev_opportunity ( standard-deviation values-from nodes [opportunity] )
  do-plotting
  if (iteration = 48) [stop]
end

;; If I don't have a coach, choose one at random. Form the link, and update the coaches num_coached variable.
to form-coach-link
  if (coachedby = "none") [
  let other-node one-of coaches with [self != myself]
     if (other-node != nobody)  and
     (not __link-neighbor? other-node)
    [
   __create-link-with other-node [ set color green ]
    set coachedby other-node
    set num_coached-of other-node num_coached-of other-node + 1
    ]
  ]
end

;; If a random number between 0-1 is less than (1 / number of nodes my coach is coaching), then I am coached this turn. Yay.
to calculate-coached-this-t
  let probability_coached 1 / (num_coached-of coachedby)
  let random_number random-float 1
  if random_number < probability_coached [
    set coached_this_t 1 set color yellow ]
  if random_number >= probability_coached [
    set coached_this_t 0 set color blue ]
end

;; If I am coached, add half of my coaches quality to my mtd. If I am not coached, subtract my mtd_decay variable from my mtd.
to calculate-mtd
  if (coached_this_t = 1) [
  set mtd mtd + ( coach_quality-of coachedby )
       ]
  if (coached_this_t = 0) [
     set mtd mtd - mtd_decay
     ]
  if (mtd < 5 ) [ set mtd 5 ]
;;  if (mtd > 95 ) [ set mtd 95 ]
end

;; Add or subtract a random number (mean 0, std. dev. 5) to my opportunity. Cap at 5 and 95.
to calculate-opportunity
  set opportunity opportunity + ( random-normal 0 5 )
  if (opportunity < 5 ) [ set opportunity 5 ]
  if (opportunity > 95 ) [ set opportunity 95 ]
end

;; My satisfaction is = my mtd.
to calculate-satisfaction
 set satisfaction mtd
 if (satisfaction > 80) [ set shape "face happy" ]
 if (satisfaction < 80) [ set shape "face neutral" ]
 if (satisfaction < 60) [ set shape "face sad" ]
 ifelse show_satisfaction? [ set label satisfaction ] [set label "" ]
end

;; Based on my age, assign a value to my seniority variable.
to calculate-seniority
  set age (age + 1)
  if (age >= 48) [ set seniority 8 set size 6 ]
  if (age < 48)  [ set seniority 6 set size 5 ]
  if (age < 42)  [ set seniority 4 set size 5 ]
  if (age < 36)  [ set seniority 2 set size 4 ]
  if (age < 30)  [ set seniority 0 set size 4 ]
  if (age < 24)  [ set seniority 0 set size 3 ]
  if (age < 18)  [ set seniority 2 set size 2 ]
  if (age < 12)  [ set seniority 4 set size 1 ]
  if (age < 6)   [ set seniority 6 set size 1 ]
end

;; If my satisfaction plus my seniority is less than my opportunity, leave. Create a new node to take my place.
to calculate-leave
  if (satisfaction + seniority < opportunity) [
    __remove-link-with coachedby
    set num_coached-of coachedby  num_coached-of coachedby - 1
    set total_attrition total_attrition + 1
    set attrition_ages ( lput age attrition_ages )
    set mean_attrition_age mean attrition_ages
  ;;  set stddev_attrition_age standard-deviation attrition_ages
    hatch 1 [
  ;;    set mtd starting-mtd
      set mtd_decay random-normal 2.5 1
      set mtd_decay avg_mtd_decay
      set opportunity random 100
      set age 0
      set coachedby "none"
      form-coach-link
    ]

  die
  ]
end



to do-plotting
  set-current-plot "Satisfaction"
    set-current-plot-pen "avg_satisfaction"
      plot mean_satisfaction
    set-current-plot-pen "avg_opportunity"
      plot mean_opportunity
    set-current-plot-pen "mean_attrition_age"
      plot mean_attrition_age
  set-current-plot "Satisfaction Detail"
    set-current-plot-pen "happy"
      plot count nodes with [shape = "face happy"]
    set-current-plot-pen "neutral"
      plot count nodes with [shape = "face neutral"]
    set-current-plot-pen "sad"
      plot count nodes with [shape = "face sad"]
end
@#$#@#$#@
GRAPHICS-WINDOW
303
10
1045
773
30
30
12.0
1
10
1
1
1
0
0
0
1
-30
30
-30
30

CC-WINDOW
5
787
1054
882
Command Center
0

SLIDER
16
12
141
45
number-of-nodes
number-of-nodes
0
100
100
1
1
NIL

BUTTON
31
234
95
267
Setup
setup
NIL
1
T
OBSERVER
T
NIL

BUTTON
99
234
162
267
Go
go
T
1
T
OBSERVER
T
NIL

SLIDER
145
12
282
45
number-of-coaches
number-of-coaches
1
100
30
1
1
NIL

SLIDER
16
48
141
81
starting-mtd
starting-mtd
0
100
100
1
1
%

PLOT
15
276
298
437
Satisfaction
Time
Value
0.0
10.0
0.0
100.0
true
true
PENS
"avg_opportunity" 1.0 0 -11221820 true
"avg_satisfaction" 1.0 0 -16777216 true
"mean_attrition_age" 1.0 0 -5825686 true

MONITOR
15
447
77
496
Iteration
iteration
3
1

MONITOR
85
447
166
496
Net Attrition
total_attrition
3
1

BUTTON
166
234
229
267
Step
go
NIL
1
T
OBSERVER
T
NIL

SLIDER
146
48
282
81
avg_coach_quality
avg_coach_quality
0
10
10
1
1
NIL

SLIDER
146
84
282
117
avg_mtd_decay
avg_mtd_decay
0
5
2.5
0.1
1
%

SWITCH
16
131
154
164
show_satisfaction?
show_satisfaction?
1
1
-1000

SWITCH
16
168
155
201
show_coached?
show_coached?
1
1
-1000

MONITOR
171
447
284
496
NIL
mean_satisfaction
3
1

PLOT
14
505
298
655
Satisfaction Detail
Time
Count
0.0
10.0
0.0
10.0
true
true
PENS
"happy" 1.0 0 -13840069 true
"neutral" 1.0 0 -16777216 true
"sad" 1.0 0 -2674135 true

@#$#@#$#@
WHAT IS IT?
-----------
This section could give a general understanding of what the model is trying to show or explain.


HOW IT WORKS
------------
This section could explain what rules the agents use to create the overall behavior of the model.


HOW TO USE IT
-------------
This section could explain how to use the model, including a description of each of the items in the interface tab.


THINGS TO NOTICE
----------------
This section could give some ideas of things for the user to notice while running the model.


THINGS TO TRY
-------------
This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.


EXTENDING THE MODEL
-------------------
This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.


NETLOGO FEATURES
----------------
This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.


RELATED MODELS
--------------
This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.


CREDITS AND REFERENCES
----------------------
This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 3.1.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Coach Number and Quality" repetitions="10" runMetricsEveryTick="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>iteration = 48</exitCondition>
    <metric>total_attrition</metric>
    <metric>mean_attrition_age</metric>
    <metric>stddev_attrition_age</metric>
    <metric>mean_satisfaction</metric>
    <metric>stddev_satisfaction</metric>
    <metric>mean_opportunity</metric>
    <metric>stddev_opportunity</metric>
    <enumeratedValueSet variable="show_satisfaction?">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="avg_coach_quality" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="starting-mtd">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show_coached?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_mtd_decay">
      <value value="2.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-coaches" first="1" step="1" last="30"/>
  </experiment>
</experiments>
@#$#@#$#@
