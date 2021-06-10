#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

#
# ============================================================================
# SPLIT CONNECTORS AT THEIR POINT OF INTERSECTION
# ============================================================================
# Written by: Zach Davis, Pointwise, Inc.
#
# This script prompts users to select two connectors they wish to split at
# common intersection points.  The connectors are then converted to database
# curves, their points of intersection are determined, and then the original
# connectors are split using these points.  Finally, the database curves and
# their points of intersection are deleted.
#

# --------------------------------------------------------
# -- INITIALIZATION
# --
# -- Load Glyph package, initialize Pointwise, and
# -- define the working directory.
# --
# --------------------------------------------------------

# Load Glyph and Tcl Libraries
package require PWI_Glyph

# Define Working Directory
set scriptDir [file dirname [info script]]

# --------------------------------------------------------
# -- USER-DEFINED PARAMETERS
# --
# -- Define a set of user-controllable settings.
# --
# --------------------------------------------------------


# --------------------------------------------------------
# -- SUBROUTINES
# --
# -- Define subroutines for frequent tasks.
# --
# --------------------------------------------------------

# Computes the Set Containing the Difference of Set1 and Set2
proc difference { set1 set2 } {
    foreach item $set1 {
        set found 0

        if { [lsearch -exact $set2 $item] < 0 } {
            set found 1
        }

        if { $found } {
            lappend set3 $item
        }
    }

    if { [info exists set3] } {
        return $set3
    } else {
        return 1
    }
}

# Query the System Clock
proc timestamp {} {
    puts [clock format [clock seconds] -format "%a %b %d %Y %l:%M:%S%p %Z"]
}

# Query the System Clock (ISO 8601 formatting)
proc timestamp_iso {} {
    puts [clock format [clock seconds] -format "%G-%m-%dT%T%Z"]
}

# Convert Time in Seconds to h:m:s Format
proc convSeconds { time } {
    set h [expr { int(floor($time/3600)) }]
    set m [expr { int(floor($time/60)) % 60 }]
    set s [expr { int(floor($time)) % 60 }]
    return [format "%02d Hours %02d Minutes %02d Seconds" $h $m $s]
}

# --------------------------------------------------------
# -- MAIN ROUTINE
# --
# -- Main meshing procedure:
# --  Acquire Connectors from User Selection
# --  Create Database Curves from Connectors
# --  Determine Points of Intersection Between Database
#     Curves
# --  Split Connectors at Intersection Points
# --  Delete Database Curves & Intersection Points
# --------------------------------------------------------

# Start Time
set tBegin [clock seconds]
timestamp

# Acquire Connectors from User Selection
set prompt1 "Please select 2 connectors to split at their intersection."
set prompt2 "Please select only 2 connectors."
set conMask [pw::Display createSelectionMask -requireConnector {}]

if { ![pw::Display getSelectedEntities -selectionmask $conMask userCons] } {
    puts "No active selection"
    set numCons 0

    while { $numCons != 2 } {
        set conSelection [pw::Display selectEntities -description $prompt1 \
                             -selectionmask $conMask userCons]

        set numCons [llength $userCons(Connectors)]

        if { $numCons < 1 } {
            puts "User canceled selection."
            exit
        }
    
        if { $numCons != 2 } {
            puts "Please select 2 connectors to split at their intersection."
        }

    }
} elseif { [llength $userCons(Connectors)] > 1 } {
    set numCons [llength $userCons(Connectors)]

    while { $numCons != 2 } {
        set conSelection [pw::Display selectEntities -description $prompt2 \
                            -selectionmask $conMask userCons]

        set numCons [llength $userCons(Connectors)]

        if { $numCons < 1 } {
            puts "User canceled selection."
            exit
        }
    }
}
            
set conFirst [lindex $userCons(Connectors) 0]
set conSecond [lindex $userCons(Connectors) 1]

# Create Database Curves from Connectors
set dbCurves [list]

foreach con $userCons(Connectors) {
    set db [pw::Curve create]
    set name "converted_"
    append name [$con getName]
    $db setName $name

    set numSegs [$con getSegmentCount]
    for { set i 1 } { $i <= $numSegs } { incr i } {
        set conSeg [$con getSegment $i]
        set dbSeg [[$conSeg getType] create]

        switch [$conSeg getType] {
            pw::SegmentCircle {
                $dbSeg addPoint [$conSeg getPoint 1]
                $dbSeg addPoint [$conSeg getPoint 2]

                switch [$conSeg getAlternatePointType] {
                    Shoulder {
                        $dbSeg setShoulderPoint [$conSeg getShoulderPoint] \
                            [$conSeg getNormal]
                    }
                    Center {
                        $dbSeg setCenterPoint [$conSeg getCenterPoint] \
                            [$conSeg getNormal]
                    }
                    Angle {
                        $dbSeg setAngle [$conSeg getAngle] [$conSeg getNormal]
                    }
                    EndAngle {
                        $dbSeg setEndAngle [$conSeg getAngle] \
                            [$conSeg getNormal]
                    }
                    default {
                    }
                }
            }
            pw::SegmentConic {
                $dbSeg addPoint [$conSeg getPoint 1]
                $dbSeg addPoint [$conSeg getPoint 2]

                switch [$conSeg getAlternatePointType] {
                    Shoulder {
                        $dbSeg setShoulderPoint [$conSeg getShoulderPoint]
                    }
                    Intersect {
                        $dbSeg setIntersectPoint [$conSeg getIntersectPoint]
                    }
                    default {
                    }
                }

                $dbSeg setRho [$conSeg getRho]
            }
            pw::SegmentSpline {
                set numPts [$conSeg getPointCount]

                for { set j 1 } { $j <= $numPts } { incr j } {
                    $dbSeg addPoint [$conSeg getPoint $j]
                }

                $dbSeg setSlope [$conSeg getSlope]

                if { [$conSeg getSlope] eq "Free" } {
                    for { set j 2 } { $j <= $numPts } { incr j } {
                        $dbSeg setSlopeIn $j [$conSeg getSlopeIn $j]
                    }

                    for { set j 1 } { $j < $numPts } { incr j } {
                        $dbSeg setSlopeOut $j [$conSeg getSlopeOut $j]
                    }
                }
            }
            pw::SegmentSurfaceSpline {
                set numPts [$conSeg getPointCount]

                for { set j 1 } { $j <= $numPts } { incr j } {
                    $dbSeg addPoint [$conSeg getPoint $j]
                }

                $dbSeg setSlope [$conSeg getSlope]

                if { [$conSeg getSlope] eq "Free" } {
                    for { set j 2 } { $j <= $numPts } { incr j } {
                        $dbSeg setSlopeIn $j [$conSeg getSlopeIn $j]
                    }

                    for { set j 1 } { $j < $numPts } { incr j } {
                        $dbSeg setSlopeOut $j [$conSeg getSlopeOut $j]
                    }
                }
            }
            default {
            }
        }

        $db addSegment $dbSeg
    }
    
    lappend dbCurves $db
}

# Determine Points of Intersection between Database Curves
set curve1Pt1 [[lindex $dbCurves 0] getXYZ -parameter 0]
set curve1Pt2 [[lindex $dbCurves 0] getXYZ -parameter 1]

set curve2Pt1 [[lindex $dbCurves 1] getXYZ -parameter 0]
set curve2Pt2 [[lindex $dbCurves 1] getXYZ -parameter 1]

set intPts [pw::Database intersect $dbCurves]

# Split Connectors at Intersection Points
foreach point $intPts {
    set pointTest1 [difference $curve1Pt1 [$point getXYZ]]
    set pointTest2 [difference $curve1Pt2 [$point getXYZ]]
    set pointTest3 [difference $curve2Pt1 [$point getXYZ]]
    set pointTest4 [difference $curve2Pt2 [$point getXYZ]]

    set x [pwu::Vector3 x [$point getXYZ]]
    set y [pwu::Vector3 y [$point getXYZ]]
    set z [pwu::Vector3 z [$point getXYZ]]
    
    if { ($pointTest1=="1")  || ($pointTest2== "1") } {
        $conSecond closestPoint -parameter conFirstSpltPt [list $x $y $z]
        $conSecond split [list $conSecondSpltPt]
    } elseif { ($pointTest3=="1")  || ($pointTest4=="1") } {
        $conFirst closestPoint -parameter conFirstSpltPt [list $x $y $z]
        $conFirst split [list $conFirstSpltPt]
    } else {
        $conFirst closestPoint -parameter conFirstSpltPt [list $x $y $z]
        $conSecond closestPoint -parameter conSecondSpltPt [list $x $y $z]

        $conFirst split [list $conFirstSpltPt]
        $conSecond split [list $conSecondSpltPt]
    }
}

# Delete Database Curves & Intersection Points
foreach curve $dbCurves {
    $curve delete
}

foreach pt $intPts {
    $pt delete
}

timestamp
puts "Run time: [convSeconds [pwu::Time elapsed $tBegin]]"

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
