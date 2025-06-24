vlib work
vlog *.*v
vsim -voptargs=+acc work.tb_top_all_layers
add wave *
run -all
#quit -sim