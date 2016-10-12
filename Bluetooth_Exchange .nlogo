extensions [ gis ]
globals [ paths-dataset   buildings_dataset patch-scale]
breed [ nodes node ]
breed [ persons person ]
breed [ BLEs BLE ]
persons-own [ to-node cur-link speed PBLE_ray Te Temp_Te De Time_to_stay]

;; ---------- startup/setup/go ----------
to startup ;; called when first loaded
  read-gis-datasets
end

to setup
  clear-all-but-globals ;; don't loose datasets
  read-gis-datasets
  ask patches [set pcolor white]
  setup-world-envelope
  display-BLE
  draw-world
  setup-paths-graph
  setup-persons
  ;;Define_BLE_RAY
  if any? links [
  let h [round link-length] of links
   set-plot-x-range 0 (max h + 1) ;set-plot-y-range 0 count links with [round link-length = 0]
  histogram [round link-length] of links
  ]
  set patch-scale (item 1 gis:world-envelope - item 0 gis:world-envelope ) / world-width

 cd
end
to go
  ask persons [move-person speed]
  check-for-Te
  check-for-other-persons

  tick ;; tick called after patch/turtle updates but before plots -- see manual
end

;; ---------- GIS related procs ----------
to read-gis-datasets
  gis:load-coordinate-system "data/buildings_small.prj"
  set buildings_dataset gis:load-dataset "data/buildings_small.shp"
  set paths-dataset     gis:load-dataset "data/roads.shp"


end
to setup-world-envelope

  let world (gis:envelope-of buildings_dataset) ;; [ minimum-x maximum-x minimum-y maximum-y ]
  if zoom != 1 [
    let x0 (item 0 world + item 1 world) / 2          let y0 (item 2 world + item 3 world) / 2
    let W0 zoom * (item 0 world - item 1 world) / 2   let H0 zoom * (item 2 world - item 3 world) / 2
    set world (list (x0 - W0) (x0 + W0) (y0 - H0) (y0 + H0))
  ]
  gis:set-world-envelope (world)
  ;; gis:set-world-envelope gis:envelope-of buildings_dataset

end
to setup-paths-graph
  set-default-shape nodes "circle"
  foreach polylines-of paths-dataset node-precision [
    (foreach butlast ? butfirst ? [ if ?1 != ?2 [ ;; skip nodes on top of each other due to rounding
        let n1 0
        let n2 0
        set n1 new-node-at first ?1 last ?1
        set n2 new-node-at first ?2 last ?2
        ask n1 [create-link-with n2
       ]

    ]])
  ]
  ask nodes [hide-turtle]
end
to-report new-node-at [x y] ; returns a node at x,y creating one if there isn't one there.
  let n nodes with [xcor = x and ycor = y]
  ifelse any? n [set n one-of n] [create-nodes 1 [setxy x y set size 2 set n self]]
  report n
end
to draw-world
  gis:set-drawing-color [102 204 255]    gis:fill buildings_dataset 0
  gis:set-drawing-color [0   0 255]    gis:draw buildings_dataset 1
  gis:set-drawing-color [255   0   0]    gis:draw paths-dataset 1
end
to-report polylines-of [dataset decimalplaces]
  let polylines gis:feature-list-of dataset                              ;; start with a features list
  set polylines map [first ?] map [gis:vertex-lists-of ?] polylines      ;; convert to virtex lists
  set polylines map [map [gis:location-of ?] ?] polylines                ;; convert to netlogo float coords.
  set polylines remove [] map [remove [] ?] polylines                    ;; remove empty poly-sets .. not visible
  set polylines map [map [map [precision ? decimalplaces] ?] ?] polylines        ;; round to decimalplaces
    ;; note: probably should break polylines with empty coord pairs in the middle of the polyline
  report polylines ;; Note: polylines with a few off-world points simply skip them.
end
to-report meters-per-patch ;; maybe should be in gis: extension?
  let world gis:world-envelope ; [ minimum-x maximum-x minimum-y maximum-y ]
  let x-meters-per-patch (item 1 world - item 0 world) / (max-pxcor - min-pxcor)
  let y-meters-per-patch (item 3 world - item 2 world) / (max-pycor - min-pycor)
  report mean list x-meters-per-patch y-meters-per-patch
end
to display-BLE
  ;;ask city-labels [ die ]
  foreach gis:feature-list-of buildings_dataset
  [ gis:set-drawing-color red
    gis:fill ? 2.0
     ; a feature in a point dataset may have multiple points, so we
      ; have a list of lists of points, which is why we need to use
      ; first twice here
      let location gis:location-of ( gis:centroid-of ? )
      ; location will be an empty list if the point lies outside the
      ; bounds of the current NetLogo world, as defined by our current
      ; coordinate transformation
      if not empty? location
      [ create-BLEs 1
        [ set xcor item 0 location
          set ycor item 1 location
          set size 1
           ] ]
      ]
end


;; ---------- persons procs ----------
to setup-persons
  set-default-shape persons "person"
  let person-size 10 / meters-per-patch
  let max-speed  (max-speed-km/h / 36) / meters-per-patch
  let min-speed  max-speed * (1 - speed-variation) ;; max-speed - (max-speed * speed-variation)
  create-persons num-persons [
    set size person-size ;; use meters-per-patch??
    set color black
    set speed min-speed + random-float (max-speed - min-speed)
    set PBLE_ray Persons_Device_Ray_Min + random-float (Persons_Device_Ray_Max - Persons_Device_Ray_Min)
    set De Exchange_duration_De
    set Temp_Te De + random (6 * De)
    let l one-of links
     if l != nobody [
       set-next-person-link l [end1] of l
       ]
  ]
end
to move-person [dist] ;; person proc
  ;;check-for-BLE
  let dxnode distance to-node
  ifelse dxnode > dist [forward dist] [
    let nextlinks [my-links] of to-node
    ifelse count nextlinks = 1
    [ set-next-person-link cur-link to-node ]
    [ set-next-person-link one-of nextlinks with [self != [cur-link] of myself] to-node ]
    move-person dist - dxnode
  ]
end
to set-next-person-link [l n] ;; person proc
  set cur-link l
  move-to n
  ifelse n = [end1] of l [set to-node [end2] of l] [set to-node [end1] of l]
  face to-node
end
to toggle-persons
  ifelse mean [size] of persons = 10
  [ ask persons [set size size / meters-per-patch set speed speed / meters-per-patch ] ]
  [ ask persons [set size 10 set speed speed * meters-per-patch ] ]
end
to check-for-BLE
  ask patches in-radius Persons_Device_Ray_Max[
     set pcolor red
    ]
end
to check-for-other-persons
   ask persons [
    ifelse count persons in-radius PBLE_ray > 1 [ set color red][ set color black]
        ]
end
to Define_BLE_RAY
  ask BLEs [
     ask patches in-radius BLE_ray[
    set pcolor red
    ]
    ]

end
to check-for-Te
  ask persons[
    let p Persons_P_Sensitivity
    ifelse Temp_Te <= 0 [ set Te  De * exp (2 - 2 * P) set Temp_Te Te ]
                  [set Temp_Te Temp_Te - 1]
    ]
end



;; ---------- One-Liners ----------

to clear-all-but-globals reset-ticks ct cp cd clear-links clear-all-plots clear-output clear-globals end

to-report mid-nodes report nodes with [count link-neighbors = 2] end
to-report end-nodes report nodes with [count link-neighbors = 1] end
to-report hub-nodes report nodes with [count link-neighbors > 2] end
to-report Avg-Te report mean [Te] of Persons  end
@#$#@#$#@
GRAPHICS-WINDOW
178
10
1978
1231
-1
-1
2.0
1
1
1
1
1
0
0
0
1
0
894
0
594
1
1
1
ticks
1.0

BUTTON
15
48
70
81
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
13
10
154
43
zoom
zoom
.1
10
0.1
.1
1
NIL
HORIZONTAL

MONITOR
86
188
157
233
Links
count links
17
1
11

MONITOR
16
188
86
233
Nodes
count nodes
17
1
11

MONITOR
6
232
63
277
De
Exchange_duration_De
17
1
11

MONITOR
59
232
116
277
Hubs
count hub-nodes
17
1
11

MONITOR
112
232
169
277
Avg_Te
mean [Te] of Persons
2
1
11

BUTTON
60
337
115
370
Hide
cd
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
337
169
370
Show
draw-world\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
14
348
61
366
Drawing
11
0.0
1

TEXTBOX
13
397
48
415
Nodes
11
0.0
1

BUTTON
58
386
113
419
Hide
ask nodes [hide-turtle]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
113
386
168
419
Show
ask nodes [show-turtle]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
16
430
155
475
Meters/Patch
meters-per-patch
10
1
11

SLIDER
14
86
156
119
num-persons
num-persons
1
1000
461
1
1
NIL
HORIZONTAL

BUTTON
99
48
154
81
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
1

SLIDER
10
489
173
522
persons-meters
persons-meters
4
10
4
.5
1
NIL
HORIZONTAL

SLIDER
14
118
156
151
max-speed-km/h
max-speed-km/h
5
60
60
5
1
NIL
HORIZONTAL

SLIDER
14
149
156
182
speed-variation
speed-variation
0
1
1
.1
1
NIL
HORIZONTAL

SLIDER
11
529
175
562
node-precision
node-precision
1
6
3
1
1
NIL
HORIZONTAL

SLIDER
11
569
175
602
BLE_ray
BLE_ray
0
50
13
1
1
NIL
HORIZONTAL

SLIDER
11
609
173
642
Persons_Device_Ray_Max
Persons_Device_Ray_Max
0
100
24
1
1
NIL
HORIZONTAL

PLOT
3
883
175
1003
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot patch-scale"

SLIDER
11
758
173
791
Proba_exchange_persons
Proba_exchange_persons
0
1
0.1
.1
1
NIL
HORIZONTAL

SLIDER
12
799
173
832
proba_exchange_person_BLE
proba_exchange_person_BLE
0
1
0.1
.1
1
NIL
HORIZONTAL

SLIDER
11
840
171
873
file_transfer_speed
file_transfer_speed
0
100
50
1
1
NIL
HORIZONTAL

BUTTON
12
289
109
322
Add citizens
toggle-persons
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
11
649
176
682
Persons_Device_Ray_Min
Persons_Device_Ray_Min
0
100
7
1
1
NIL
HORIZONTAL

SLIDER
11
688
176
721
Exchange_duration_De
Exchange_duration_De
0
400
60
1
1
NIL
HORIZONTAL

SLIDER
10
724
176
757
Persons_P_Sensitivity
Persons_P_Sensitivity
0
1
0
.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model was built to test and demonstrate the functionality of the GIS NetLogo extension.  In particular, the feasability of using NetLogo and GIS to study boat traffic in Venice, Italy.

## HOW IT WORKS

This model uses 4 GIS datasets of the Venice area.  Three of the datasets are polygon shape files, one is a polyline dataset.  The latter shows the "channels" used to mark safe (deep) areas of the Venice lagoon.

Two additional "objects" are introduced to the datasets:
1 - A graph is created from the channels data set, using a "nodes" turtle breed and standard unidirectional links.
2 - A boat turtle breed is introduced which can follow the graph links above, given a realistic traffic facility.

We use a facility enabled by the GIS extension: we can use realistic world coordinates.  Thus the boats are realistic in size (thus invisible!) and the speeds are realistic.

We also use a useful trick Stephen Guerin found: have the boats off-center.  This means they can be offset from the center of the canals without arduous calculations.  They naturally end up on the right side of the centerline.  Use the Shape Editor to see the off-center design.

## HOW TO USE IT

The model uses the GIS data to allow boat traffic to be studied.  The scene is centered on the primary lagoons surrounding Venice (orange).  The scene can zoom in or out usin the zoom slider.

To initialize the model, set the number of boats, zoom level, and speed max & variation.  Click "setup" which will create the scene and initialize the boats.

Note the datasets are read in *before* the model is displayed, using the startup procedure which is run when netlogo first reads in the model.  This means that the datasets are read in only once.  This makes the initialization within the setup procedure clear all *but* the globals.

The 5 monitors showing the node and link statistics are there mainly for our debugging purposes, and for tuning the model.  The nodes/links monitors show the size of the graph.  The Ends monitor shows nodes with just one link.  The Mids monitor, those with 2.  Hubs are 3 or more and provide the "intersections" between canal segments.

Note that NetLogo can handle very large graphs .. we often have 7000 or more nodes and links.  You can tune the number of nodes/links by changing the node-precision slider below the map.  This parameter is used to round the netlogo coordinates which have huge precision to simpler numbers.

The boat behavior is dead simple: move along links at their allocated speed, turning at intersections with equal probability.

## THINGS TO TRY

- Note that the boats are invisible.  To make them visible in the standard 2D view, you can use the command center to ask the boats to be a patch or two in length.  This is very unrealistic but useful initially.

- To make the boats visible without resizing, you will have to use the 3D view.  Click on the 3D button above the map, and zoom in and pan around.  Note how essential this is for GIS modeling!

- Try zooming in/out to see the traffic at different scales of the Venice lagoon area.  Note how useful this is with the 3D view again.

- Show/hide the drawing and nodes via the buttons below the map.  Use the command center to make the nodes large (size 4, say) and the links thick (thickness of 2, say).

- Try different world sizes.  We use a 1-pixel patch which is really small!  Try to guess what happens with 4 pixel patches.

- Try different values for node-precision to see if the graph gets larger or smaller in terms of number of nodes and links.

## EXTENDING THE MODEL

The current model is simply a feasablility study.  Several improvements can be made:
- More boat types.  There are 19 boat types in the Forma Urbis data.

- More GIS layers.  The initial study by Forma Urbis has boat traffic details that would be nicely integrated into the model.

- Introduce realistic behavior and goals along with more details of Venice such as one-way canals.

- Let the boats be arbitrary distances from the centerline rather than the single offset provided by the off-center boat design.

- Build a "thining" procedure which goes through the graph, eliminating nodes that are basically in a straight line with their neighbors.  Does this reduce the size of the graph significantly?  At every zoom level?  Does it improve the performance of the model?

.. and so on!

## RELATED MODELS

The sample models included with the GIS extension are invaluable for understanding how to get started with NetLogo and GIS.

## CREDITS AND REFERENCES

Eric Russell built the GIS extension used by the model, and responded to all our questions and requests for changes.  Thanks Eric!
  http://ccl.northwestern.edu/netlogo/4.0/extensions/gis/

The model is an exploration by Stephen Guerin and Owen Densmore of the RedFish Group:
  http://redfish.com/

Fabio Carrera (WPI, Forma Urbis) suggested Venice water traffic simulation to Stephen and myself, and provided the GIS data used in this model.
  http://www.wpi.edu/Academics/Depts/IGSD/People/fc.html
  http://users.wpi.edu/~carrera/

Daniela Pavan and Andrea Novello of Forma Urbis helped Stephen and myself understand the various GIS layers and their use in water traffic studies.
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

boat
true
0
Polygon -7500403 true true 180 300 270 300 300 75 225 0 150 75

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
NetLogo 5.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
