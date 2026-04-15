set paths [get_timing_paths -setup -slack_lesser_than 0 -max_paths 50]

foreach p $paths {

    foreach n [get_nets -of_objects $p] {
        set fo [get_property FLAT_PIN_COUNT $n]
        if {$fo >= 100} {
            set_property MAX_FANOUT 64 [get_nets $n]
	}
    }
}