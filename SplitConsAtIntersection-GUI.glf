#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

###############################################################################
# Split two connectors wherever they intersect
###############################################################################

package require PWI_Glyph 2
pw::Script loadTk

# Globals
set con1 ""
set con1Name ""
set con2 ""
set con2Name ""

# Widget hierarchy
set w(LabelTitle)               .title
set w(FrameMain)                .main
set   w(FramePick)                $w(FrameMain).pick
set     w(ButtonPick1)              $w(FramePick).bPick1
set     w(ButtonPick2)              $w(FramePick).bPick2
set   w(FrameSelection)           $w(FrameMain).selection
set     w(LabelSelection)           $w(FrameSelection).lbl
set     w(LabelCon1)                $w(FrameSelection).con1
set     w(LabelCon2)                $w(FrameSelection).con2
set     w(ButtonClear)              $w(FrameSelection).bClear
set w(FrameButtons)             .buttons
set   w(Logo)                     $w(FrameButtons).logo
set   w(ButtonOK)                 $w(FrameButtons).bOk
set   w(ButtonApply)              $w(FrameButtons).bApply
set   w(ButtonCancel)             $w(FrameButtons).bCancel


# Select one connector from the GUI
proc pickConnector {} {
  set con ""
  if {[pw::Grid getCount -type pw::Connector] > 0} {
    wm withdraw .
    pw::Display selectEntities -description "Pick connector to split:" \
      -selectionmask [pw::Display createSelectionMask -requireConnector {}] \
      -single resultArray
    set con $resultArray(Connectors)
    if {[winfo exists .]} {
      wm deiconify .
    }
  }
  return $con
}


# Create a (temporary) database curve from the shape of the given connector
proc generateCurveFromShape {con} {
  set curve [pw::Curve create]
  set segCount [$con getSegmentCount]
  for {set i 1} {$i <= $segCount} {incr i} {
    $curve addSegment [$con getSegment -copy $i]
  }
  return $curve
}


# Use a database curve representation of each connector to determine the
# intersection point. Then split each connector at closestPoint to intersection
proc findIntersectionAndSplit {} {
  global con1 con2
  if {"" != $con1 && "" != $con2} {
    set creator [pw::Application begin Create]
    #Create temporary database curve copies of the connectors
    set curve1 [generateCurveFromShape $con1]
    set curve2 [generateCurveFromShape $con2]
    #Find intersection points of database curves
    set dbPts [pw::Database intersect $curve1 $curve2]
    $creator end

    if {[list] == $dbPts} {
      puts "WARNING:  No intersection points found"
      return
    }

    set tol [pw::Grid getNodeTolerance]
    set spPar1 [list]
    set spPar2 [list]
    foreach pt $dbPts {
      #Find corresponding points on the connectors
      $con1 closestPoint -parameter par [$pt getXYZ]
      if {$par > $tol && [expr 1.0 - $par] > $tol} {
        lappend spPar1 $par
      }
      $con2 closestPoint -parameter par [$pt getXYZ]
      if {$par > $tol && [expr 1.0 - $par] > $tol} {
        lappend spPar2 $par
      }
      #Delete the database points
      $pt delete
    }
    #Delete the database curves
    $curve1 delete
    $curve2 delete

    #Split the connectors
    if {[catch {$con1 split $spPar1}]} {
      puts "WARNING:  Could not split connector [$con1 getName]"
    }
    if {[catch {$con2 split $spPar2}]} {
      puts "WARNING:  Could not split connector [$con2 getName]"
    }
  }
}


# Set the font for the title frame
proc setTitleFont { l } {
  global titleFont
  if { ! [info exists titleFont] } {
    set fontSize [font actual TkCaptionFont -size]
    set titleFont [font create -family [font actual TkCaptionFont -family] \
        -weight bold -size [expr {int(1.5 * $fontSize)}]]
  }
  $l configure -font $titleFont
}


# Apply incoming selection if either exactly one or exactly two connectors
proc getPreSelection {} {
  global con1 con1Name con2 con2Name
  if {[pw::Display getSelectedEntities \
        -selectionmask [pw::Display createSelectionMask -requireConnector {}] \
        resultArray]} {
    set selection $resultArray(Connectors)
    if {2 == [llength $selection]} {
      set con1 [lindex $selection 0]
      set con1Name [$con1 getName]
      set con2 [lindex $selection 1]
      set con2Name [$con2 getName]
    } elseif {1 == [llength $selection]} {
      set con1 [lindex $selection 0]
      set con1Name [$con1 getName]
    }
  }
}


# Build user interface
proc makeWindow {} {
  global w con1 con2 tol

  wm title . "Split At Intersection"
  
  label $w(LabelTitle) -text "Split Two Connectors\nWhere They Intersect"
  setTitleFont $w(LabelTitle)

  frame $w(FrameMain)

  frame $w(FramePick)
  button $w(ButtonPick1) -text "Select First Connector" -command {
    set con1 [pickConnector]
    set con1Name [$con1 getName]
  } -width 20
  button $w(ButtonPick2) -text "Select Second Connector" -command {
    set con2 [pickConnector]
    set con2Name [$con2 getName]
  } -width 20

  frame $w(FrameSelection)
  label $w(LabelSelection) -text "Connectors selected:"
  label $w(LabelCon1) -textvariable con1Name
  label $w(LabelCon2) -textvariable con2Name
  button $w(ButtonClear) -text "Clear Selection" -command {
    set con1 ""
    set con1Name ""
    set con2 ""
    set con2Name ""
  }

  frame $w(FrameButtons)
  button $w(ButtonCancel) -text "Cancel" -command {exit}
  button $w(ButtonApply) -text "Apply" -command {
    findIntersectionAndSplit
    pw::Display update
  }
  button $w(ButtonOK) -text "OK" -command {
    $w(ButtonApply) invoke
    $w(ButtonCancel) invoke
  }
  label $w(Logo) -image [cadenceLogo] -bd 0 -relief flat

  pack $w(LabelTitle) -side top
  
  pack [frame .sp1 -bd 1 -height 2 -relief sunken] -side top -fill x -pady 5

  pack $w(FrameMain)
  
  pack $w(FramePick)
  pack $w(ButtonPick1) -side left -padx 3
  pack $w(ButtonPick2) -side left -padx 3

  pack $w(FrameSelection)
  pack $w(LabelSelection)
  pack $w(LabelCon1)
  pack $w(LabelCon2)
  pack $w(ButtonClear) -pady 3
  
  pack [frame .sp2 -bd 1 -height 2 -relief sunken] -side top -fill x -pady 5

  pack $w(FrameButtons) -side bottom -fill x -ipadx 5 -ipady 2
  pack $w(ButtonCancel) -side right -padx 3
  pack $w(ButtonApply) -side right -padx 3
  pack $w(ButtonOK) -side right -padx 3
  pack $w(Logo) -side left -padx 3

  bind . <Key-Return> {$w(ButtonApply) invoke}
  bind . <Control-Key-Return> {$w(ButtonOK) invoke}
  bind . <Key-Escape> {$w(ButtonCancel) invoke}
  bind $w(ButtonOK) <Key-Return> {
    $w(ButtonOK) flash
    $w(ButtonOK) invoke
  }
  bind $w(ButtonApply) <Key-Return> {
    $w(ButtonApply) flash
    $w(ButtonApply) invoke
  }
  bind $w(ButtonCancel) <Key-Return> {
    $w(ButtonCancel) flash
    $w(ButtonCancel) invoke
  }
  
  wm resizable . 0 0
}

proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

getPreSelection
makeWindow
::tk::PlaceWindow . widget
tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
