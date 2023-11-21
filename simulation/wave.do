onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic -radix hexadecimal /htl8254_tb/resetn
add wave -noupdate -format Logic /htl8254_tb/clk
add wave -noupdate -format Logic /htl8254_tb/a0
add wave -noupdate -format Logic /htl8254_tb/a1
add wave -noupdate -format Logic -radix hexadecimal /htl8254_tb/csn
add wave -noupdate -format Logic -radix hexadecimal /htl8254_tb/rdn
add wave -noupdate -format Logic -radix hexadecimal /htl8254_tb/wrn
add wave -noupdate -format Literal -radix hexadecimal /htl8254_tb/dbus_in
add wave -noupdate -format Literal -radix hexadecimal /htl8254_tb/dbus_out
add wave -noupdate -format Literal -radix unsigned /htl8254_tb/u_0/t0/u_2/mode
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_3/modepulse
add wave -noupdate -divider Diagram
add wave -noupdate -format Logic /htl8254_tb/u_0/wrn
add wave -noupdate -format Logic /htl8254_tb/clk0
add wave -noupdate -format Logic -radix hexadecimal /htl8254_tb/gate0
add wave -noupdate -format Logic -radix hexadecimal /htl8254_tb/out0
add wave -noupdate -format Literal -radix hexadecimal /htl8254_tb/u_0/t0/u_0/counter_s
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_2/outo
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/outo_s
add wave -noupdate -format Literal /htl8254_tb/u_0/t0/u_2/current_state
add wave -noupdate -format Literal /htl8254_tb/u_0/t0/u_2/next_state
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_2/outo_cld
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_0/cnt_en
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_0/clken
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_3/gatelevel_s
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_3/cnt_en_m2
add wave -noupdate -format Logic /htl8254_tb/u_0/t0/u_3/gate_en_s
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {17190 ns} 0}
configure wave -namecolwidth 141
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {6938 ns} {25734 ns}
