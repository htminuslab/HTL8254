@REM ------------------------------------------------------
@REM Simple DOS batch file to compile and run the testbench
@REM Ver 1.0 HT-Lab 2002
@REM Tested with Modelsim 5.8c
@REM ------------------------------------------------------
vlib work

@REM Compile HTL8254 

vcom -93 -quiet -work work ../rtl/cemodule.vhd
vcom -93 -quiet -work work ../rtl/ctrlword.vhd
vcom -93 -quiet -work work ../rtl/ctrlout.vhd
vcom -93 -quiet -work work ../rtl/gateclk.vhd
vcom -93 -quiet -work work ../rtl/edge3ff.vhd
vcom -93 -quiet -work work ../rtl/timer.vhd
vcom -93 -quiet -work work ../rtl/htl8254.vhd

@REM Compile Testbench

vcom -93 -quiet -work work ../testbench/utils.vhd
vcom -93 -quiet -work work ../testbench/htl8254_tester.vhd
vcom -93 -quiet -work work ../testbench/htl8254_tb.vhd

@REM Run simulation
vsim HTL8254_tb -c -do "set StdArithNoWarnings 1; run -all; quit -f"
