
;;;;;;;;;;;;;;;;;
;;; Variables ;;;
;;;;;;;;;;;;;;;;;

patches-own [
  chemical             ;; amount of chemical on this patch
  danger-chemical      ;; amount of danger pheromones left by ants
  danger?              ;; true on dangerous patches, false elsewhere
  food?                ;; true if center-patch has food
  food-center?
  nest-deposited-food
  food                 ;; amount of food on this patch (0, 1, or 2)
  nest?                ;; true on nest patches, false elsewhere
  nestfood             ;; food in the nest
  nest-scent           ;; number that is higher closer to the nest
  food-source-number   ;; number (1, 2, or 3) to identify the food sources
  foragerActive?       ;; true once the first scout reaches the nest with food, false before
  secondTicks          ;; variable that holds the number of ticks it takes until the first food reaches the nest
  foragerReturn?       ;; true once the first forager returns, false before
  health
  food-discovered?
  food-distance
]

breed [scouts scout]
breed [foragers forager]

turtles-own [
  food-carry-color     ;;
  danger-chemical-ant  ;; amount of fear-pheromone present on the current ant
]

scouts-own [
  energy
  turtle-color
  ]    ;; energy for each scout
foragers-own [
  energy
  turtle-color
  ]  ;; energy for each forager


;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  pre-init-food
  setup-scouts
  setup-foragers
  setup-patches
  reset-ticks
end

to setup-scouts
  set-default-shape scouts "bug"
  create-scouts amount_scouts
  [ set size 2         ;; easier to see
    set food-carry-color yellow
    set turtle-color blue     ;; red = not carrying food
    set color turtle-color
    set  energy startenergy ]  ;; power level of the ants
end

to setup-foragers               ;; setup foragers
  set-default-shape foragers "bug"
  create-foragers amount_foragers
  [ set size 2         ;; easier to see
    set food-carry-color yellow
    set turtle-color green
    set color turtle-color      ;; blue = not carrying food
    set energy startenergy ]  ;; power level of the ants
end

to setup-patches
  ask patches
  [ setup-nest
    setup-food
    setup-danger
    recolor-patch ]
end

to pre-init-food
  let i  1
  while [i < number-food + 1] [
      set i i + 1

      let xcoor random-pxcor
      let ycoor random-pycor

      ask patch xcoor ycoor
      [
        print xcoor
        set food-discovered? false
        set food-center? true
        set food-distance abs(distancexy xcoor ycoor - distancexy 0 0)
        set food one-of [1 2]
        set food-source-number i
        set nest-deposited-food 0
      ]

      ]
end

to setup-nest  ;; patch procedure
  ;; set nest? variable to true inside the nest, false elsewhere
  set nest? (distancexy 0 0) < 5
  ;; spread a nest-scent over the whole world -- stronger near the nest
  set nest-scent 200 - distancexy 0 0

  if distancexy 0 0 < 5
  [set nestfood ( startfood / 75.9 )]
end

;;;;;;;;;;;;;;;;;;
;; Experimental ;;
;;;;;;;;;;;;;;;;;;

to setup-food  ;; patch procedure

  if food-center? = true
  [
    let fsn food-source-number
    let fds food
    let fdist food-distance
    let food-size random (max-food-size - min-food-size) + min-food-size
    ask patches in-radius food-size [
          set food? true
          set food fds
          set food-distance fdist
          set food-source-number fsn
          set nest-deposited-food 0
     ]
  ]
end

to recolor-patch  ;; patch procedure
  ; give color to nest and food sources
  ifelse nest?
  [ set pcolor violet ]
  [ ifelse food > 0
     [ set pcolor blue]
    [ifelse danger? != 0
      [set pcolor red]
      [color-chemicals]
    ]
  ]
end

to color-chemicals ;; scale color to show chemical concentration
  ifelse chemical > danger-chemical
    [set pcolor scale-color green ((chemical) - (danger-chemical)) 0.1 5]
    [set pcolor scale-color red ((danger-chemical) - (chemical)) 0.1 5]
end

to setup-danger ;; patch procedure
  if danger-enabled
  [  if (distancexy (0.8 * max-pxcor) (0.8 * max-pycor)) < 5
  [ set danger? true]]

end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  if count turtles < 1
  [stop]
  let forager-parameters nest-forager-activity
  turtles-per-tick forager-parameters
  chemicals-per-tick
  ask turtles
  [ can-i-eat ]
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;
;;; Tick procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to turtles-per-tick [forager-parameters]
  scouts-per-tick
  foragers-per-tick forager-parameters
  ask turtles
  [ set energy energy - 1
    critical-condition
  ]
end

to scouts-per-tick
  ask scouts
  [ if who >= ticks [ stop ]
     explore
  ]
end

to foragers-per-tick [forager-parameters]
  if (item 0 forager-parameters) = true ; maybe replace this with if the foragers can smell the chemical?
  [ ask foragers
    [ if who + ( item 1 forager-parameters - amount_scouts ) >= ticks [ stop ] ;; delay initial departure
      check-in-with-foragers
    ] ]
end


to chemicals-per-tick
  diffuse chemical (diffusion-rate / 100)
  diffuse danger-chemical (diffusion-rate / 1000)

  ask patches
  [ set chemical chemical * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical
    set danger-chemical danger-chemical * ((100 - evaporation-rate) + evaporation-rate / 1.5 ) / 100
    recolor-patch ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Activity procedure ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report nest-forager-activity
    let forager-return false
    let forager-active false
    let second-ticks 0
    ask patches with [nest?] [
       ifelse foragerActive? = true
       [ set forager-active true
         set second-ticks secondTicks ]
       [ set forager-active false ]

;       ifelse foragerReturn? = true
 ;      [ set forager-return false ]
  ;     [ set forager-return true ]
    ]


    let result list (forager-active) (second-ticks)
    set result list (forager-active) (second-ticks)
    report result
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Slice-of-life procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to explore
  ifelse color = turtle-color
    [ look-for-food  ] ;; if color of ants is neutral, they walk around and explore
    [ decide-plan ]
  move
end

;;so they are not looking for food, they must be wanting to do something else: what state are they thus in?
to decide-plan
  if color = food-carry-color ;; if not neutral, and they are in a state of panic
      [ return-to-nest ] ;; if the ants are neither neutral nor in danger, they will return to the nest
end

to move
  wiggle
  fd 1
end

to look-for-food
  let danger-compare get-strongest-danger-chemical
  let food-compare get-strongest-food-chemical

  ifelse food > 0 ;; if the ants stumble on a patch of food
    [grab-food] ;; grab food
  [ifelse danger? = true ;;if the ants encounter an enemy
     [enemy-encounter] ;;flee or fight the enemy
  [ifelse (chemical >= 0.05) and (chemical < 2) ;; if the ants encounter spores of enemy
     [
       if turtle-color = green and count foragers < 5
       [print "get food"]
       uphill-chemical]
  [if (danger-compare > food-compare)
     [ danger-chemical-encounter ]
  ]] ]

end

;;;;;;;;;;;;;;;;;;;;;;;
;;; Food procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to can-i-eat
  let foodsource sum[nestfood] of patches in-radius nest-size with [nest?]

  if (energy < hunger-threshold) and (foodsource > 0)
  [eat foodsource]
end

to eat [foodsource]
  set foragerActive? true
  ask one-of patches in-radius nest-size with [nest?]
  [set nestfood nestfood - 1]
  set energy energy + EnergyperFood
end

to grab-food  ;; turtle procedure
  set color food-carry-color     ;; pick up food
    set food food - 1        ;; and reduce the food source
    set food-discovered? true
    rt 180                   ;; and turn around
    stop
end

to return-to-nest  ;; turtle procedure
  ifelse nest?
  [ arrived-at-nest ]
  [ going-to-nest  ]
end

to going-to-nest
   if color = food-carry-color
   [set chemical chemical + food-chemical-strength]  ;; drop some chemical
   uphill-nest-scent
end

to arrived-at-nest
  set color turtle-color
  set nestfood nestfood + 1
  set nest-deposited-food nest-deposited-food + 1
  can-i-eat
  scouts-arrived-at-nest
  foragers-arrived-at-nest
end

to scouts-arrived-at-nest
  if turtle-color = blue
  [ wakeUpForagers
      rt 180]
end

to foragers-arrived-at-nest
  if turtle-color = green
  [
  ]
end

to rest
  can-i-eat
end
;;;;;;;;;;;;;;;;;;;;;;;;
;;; Scout procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to wakeUpForagers
  ask patches with [nest? = true];; in-radius 100
    [ if foragerActive? != true
      [ set foragerActive? true
      set secondTicks ticks
      ] ]
end

to scout-in-danger-chemical
  downhill-danger-chemical
end

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Forager procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

to check-in-with-foragers
  ifelse(energy < hunger-threshold)
  [ explore ]
  [ can-i-explore ]
end

to can-i-explore
  ifelse (nest? and detect-chemical-presence = false)
  [ rest ]
  [ explore ]
end

to forager-in-danger-chemical
  ifelse(energy < hunger-threshold)
  [ uphill-danger-chemical ]
  [ downhill-danger-chemical]
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Danger procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

to enemy-encounter

  if turtle-color = blue
  [ scout-in-enemy-encounter ]

  if turtle-color = green
  [ forager-in-enemy-encounter ]

end

to forager-in-enemy-encounter
  let xcoor xcor
  let ycoor ycor ask patches in-radius 10

[ set danger-chemical 10 - distancexy xcoor ycoor ]
  let turtlesc count turtles-on patches in-radius (enemy-size + 2) with [danger? = true]
  let companions count turtles-on patches in-radius (3)

  if companions >= soldiers-to-kill
  [ kill-enemy ]

  die
end

to kill-enemy
  print "Death"
  ask patches in-radius (10 + enemy-size ) with [danger? = true]
  [turn-enemy-into-food]
end

to turn-enemy-into-food
  set danger? false
  set food? true
  set food 2
  recolor-patch
end

to scout-in-enemy-encounter
  let xcoor xcor
  let ycoor ycor ask patches in-radius 10
[     set danger-chemical danger-chemical-strength  - distancexy xcoor ycoor
  ]
  die
end

to danger-chemical-encounter
  if turtle-color = blue
  [ scout-in-danger-chemical ]

  if turtle-color = green
  [ forager-in-danger-chemical ]
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Sniff procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;


to-report get-strongest-food-chemical
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45

  ifelse (scent-ahead > scent-right) or (scent-ahead > scent-left)
  [ ifelse scent-right > scent-left
    [ report scent-right
       ]
    [ report scent-left
      ]  ]
  [ report scent-ahead ]
end



to-report get-strongest-danger-chemical
  let scent-ahead danger-chemical-at-angle   0
  let scent-right danger-chemical-at-angle  45
  let scent-left  danger-chemical-at-angle -45

  ifelse (scent-ahead > scent-right) or (scent-ahead > scent-left)
  [ ifelse scent-right > scent-left
    [ report scent-right
       ]
    [ report scent-left
      ]  ]
  [ report scent-ahead ]
end

to downhill-danger-chemical
  let scent-ahead danger-chemical-at-angle   0
  let scent-right danger-chemical-at-angle  45
  let scent-left  danger-chemical-at-angle -45
  if (scent-ahead > scent-right) or (scent-ahead > scent-left)
  [ ifelse scent-right > scent-left
    [ lt 45
       ]
    [ rt 45
      ] ]
end

to uphill-danger-chemical  ;; turtle procedure
  let scent-ahead danger-chemical-at-angle   0
  let scent-right danger-chemical-at-angle  45
  let scent-left  danger-chemical-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

to-report detect-chemical-presence
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45

  ifelse (scent-right > chemical-scent-threshold) or (scent-ahead > chemical-scent-threshold) or (scent-left > chemical-scent-threshold)
  [ report true ]
  [ report false ]
end

;;When looking for food, sniffs chemical, and rotate towards the strongest smell
to uphill-chemical  ;; turtle procedure
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

;;When carrying food back to the nest, sniffs the nest's scent, and rotates towards the strongest smell.
to uphill-nest-scent  ;; turtle procedure
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

;;Input: an angle
;;Output: the strength of the danger-chemical-scent at [angle]
to-report danger-chemical-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [danger-chemical] of p
end

;;Input: an angle
;;Output: the strength of the nest-scent at [angle]
to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

;;Input: an angle
;;Output: the strength of the chemical-scent at [angle]
to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical] of p
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Helper procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

to wiggle  ;; turtle procedure
;  ifelse color = blue
   rt random 40
   lt random 40
;  [ rt random 2
;    lt random 2 ]
  if not can-move? 1 [ rt 180 ]
  set energy energy - 1
end



to critical-condition ;; turtle procedure
  if energy <= 0
  [ ifelse color = food-carry-color
    [ set color turtle-color
      set energy energy + EnergyperFood
      look-for-food
    ]
    [die]
  ]
end

; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
257
10
764
434
-1
-1
7.0
1
10
1
1
1
0
0
0
1
-50
20
-35
20
1
1
1
ticks
30.0

BUTTON
35
12
115
45
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
35
188
225
221
diffusion-rate
diffusion-rate
0.0
99.0
80
1.0
1
NIL
HORIZONTAL

SLIDER
37
225
227
258
evaporation-rate
evaporation-rate
0.0
99.0
10
1.0
1
NIL
HORIZONTAL

BUTTON
135
12
210
45
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
1054
413
1297
692
Food in each pile
time
food
0.0
50.0
0.0
120.0
true
false
"" ""
PENS
"food-in-pile1" 1.0 0 -11221820 true "" "plotxy ticks sum [food] of patches with [pcolor = cyan]"
"food-in-pile2" 1.0 0 -13791810 true "" "plotxy ticks sum [food] of patches with [pcolor = sky]"
"food-in-pile3" 1.0 0 -13345367 true "" "plotxy ticks sum [food] of patches with [pcolor = blue]"

SLIDER
37
342
232
376
number-food
number-food
0
15
2
1
1
NIL
HORIZONTAL

SLIDER
795
58
967
91
amount_scouts
amount_scouts
0
200
60
1
1
NIL
HORIZONTAL

SLIDER
795
103
967
136
amount_foragers
amount_foragers
0
200
40
1
1
NIL
HORIZONTAL

SLIDER
40
570
238
604
StartEnergy
StartEnergy
0
800
106
1
1
NIL
HORIZONTAL

SLIDER
42
613
241
647
EnergyperFood
EnergyperFood
0
800
156
1
1
NIL
HORIZONTAL

SLIDER
39
295
232
329
food-chemical-strength
food-chemical-strength
0
100
50
1
1
NIL
HORIZONTAL

PLOT
1054
32
1254
182
Population Ants
Amount of Ants
Time
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count foragers"
"pen-1" 1.0 0 -7500403 true "" "plot count scouts"

SLIDER
42
664
241
698
Startfood
Startfood
0
800
178
1
1
NIL
HORIZONTAL

PLOT
1047
224
1247
374
Nestfood
time
food
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks sum [nestfood] of patches with [pcolor = violet\n]"

SLIDER
39
122
236
156
hunger-threshold
hunger-threshold
200
600
200
1
1
NIL
HORIZONTAL

SLIDER
40
84
234
118
chemical-scent-threshold
chemical-scent-threshold
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
38
518
233
552
nest-size
nest-size
1
10
5
1
1
NIL
HORIZONTAL

SLIDER
37
387
230
421
min-food-size
min-food-size
0
10
4
1
1
NIL
HORIZONTAL

SLIDER
34
432
229
466
max-food-size
max-food-size
0
10
4
1
1
NIL
HORIZONTAL

TEXTBOX
85
63
273
86
Thresholds
11
0.0
1

TEXTBOX
90
169
278
192
Chemical rates\n
11
0.0
1

TEXTBOX
82
270
270
293
Food variables
11
0.0
1

TEXTBOX
97
497
285
520
Nest variables
11
0.0
1

TEXTBOX
828
37
1016
60
Colony Ratio setup
11
95.0
1

SLIDER
860
199
1033
233
enemy-size
enemy-size
0
100
8
1
1
NIL
HORIZONTAL

SLIDER
377
587
596
621
danger-chemical-strength
danger-chemical-strength
0
100
14
1
1
NIL
HORIZONTAL

SLIDER
407
709
580
743
soldiers-to-kill
soldiers-to-kill
0
10
3
1
1
NIL
HORIZONTAL

SWITCH
392
477
545
511
danger-enabled
danger-enabled
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

In this project, a colony of ants forages for food. Though each ant follows a set of simple rules, the colony as a whole acts in a sophisticated way.

## HOW IT WORKS

When an ant finds a piece of food, it carries the food back to the nest, dropping a chemical as it moves. When other ants "sniff" the chemical, they follow the chemical toward the food. As more ants carry food to the nest, they reinforce the chemical trail.

## HOW TO USE IT

Click the SETUP button to set up the ant nest (in violet, at center) and three piles of food. Click the GO button to start the simulation. The chemical is shown in a green-to-white gradient.

The EVAPORATION-RATE slider controls the evaporation rate of the chemical. The DIFFUSION-RATE slider controls the diffusion rate of the chemical.

If you want to change the number of ants, move the POPULATION slider before pressing SETUP.

## THINGS TO NOTICE

The ant colony generally exploits the food source in order, starting with the food closest to the nest, and finishing with the food most distant from the nest. It is more difficult for the ants to form a stable trail to the more distant food, since the chemical trail has more time to evaporate and diffuse before being reinforced.

Once the colony finishes collecting the closest food, the chemical trail to that food naturally disappears, freeing up ants to help collect the other food sources. The more distant food sources require a larger "critical number" of ants to form a stable trail.

The consumption of the food is shown in a plot.  The line colors in the plot match the colors of the food piles.

## EXTENDING THE MODEL

Try different placements for the food sources. What happens if two food sources are equidistant from the nest? When that happens in the real world, ant colonies typically exploit one source then the other (not at the same time).

In this project, the ants use a "trick" to find their way back to the nest: they follow the "nest scent." Real ants use a variety of different approaches to find their way back to the nest. Try to implement some alternative strategies.

The ants only respond to chemical levels between 0.05 and 2.  The lower limit is used so the ants aren't infinitely sensitive.  Try removing the upper limit.  What happens?  Why?

In the `uphill-chemical` procedure, the ant "follows the gradient" of the chemical. That is, it "sniffs" in three directions, then turns in the direction where the chemical is strongest. You might want to try variants of the `uphill-chemical` procedure, changing the number and placement of "ant sniffs."

## NETLOGO FEATURES

The built-in `diffuse` primitive lets us diffuse the chemical easily without complicated code.

The primitive `patch-right-and-ahead` is used to make the ants smell in different directions without actually turning.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was developed at the MIT Media Lab using CM StarLogo.  See Resnick, M. (1994) "Turtles, Termites and Traffic Jams: Explorations in Massively Parallel Microworlds."  Cambridge, MA: MIT Press.  Adapted to StarLogoT, 1997, as part of the Connected Mathematics Project.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 1998.

<!-- 1997 1998 MIT -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

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
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Distance-to-food-small map" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>amount_scouts + amount_foragers != 100</exitCondition>
    <metric>[ (list food-distance)] of patches with [food? = true and food-center? = true]</metric>
    <metric>remove-duplicates [ (list food-distance)] of patches with [food-discovered? = true]</metric>
    <metric>filter [not member? ? [ (list food-distance)] of patches with [food-discovered? = true] ] [ (list food-distance)] of patches with [food? = true and food-center? = true]</metric>
    <metric>sum([nest-deposited-food]) of patches with [nest? = true]</metric>
    <metric>count patches with [food-discovered? = true]</metric>
    <metric>count patches with [food? = true]</metric>
    <enumeratedValueSet variable="max-pxcor">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pycor">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="amount_scouts">
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="amount_foragers">
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
