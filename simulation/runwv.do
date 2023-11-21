vcom -93 -quiet -work work ../rtl/cemodule.vhd
vcom -93 -quiet -work work ../rtl/ctrlword.vhd
vcom -93 -quiet -work work ../rtl/ctrlout.vhd
vcom -93 -quiet -work work ../rtl/gateclk.vhd
vcom -93 -quiet -work work ../rtl/edge3ff.vhd
vcom -93 -quiet -work work ../rtl/timer.vhd
vcom -93 -quiet -work work ../rtl/htl8254.vhd
vcom -93 -quiet -work work ../testbench/utils.vhd
vcom -93 -quiet -work work ../testbench/htl8254_tester_wave.vhd
vcom -93 -quiet -work work ../testbench/htl8254_tb.vhd
vsim HTL8254_tb 
set StdArithNoWarnings 1;
do wavediagram.do
run -all