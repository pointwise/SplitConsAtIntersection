#
# Copyright 2015 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

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
  label $w(Logo) -image [pwLogo] -bd 0 -relief flat

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

proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}

getPreSelection
makeWindow
::tk::PlaceWindow . widget
tkwait window .

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED 
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY 
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES 
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF 
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE 
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE 
# FAULT OR NEGLIGENCE OF POINTWISE.
#
