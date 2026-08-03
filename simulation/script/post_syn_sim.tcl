xrun -gui -ieee1364 -sv -disable_sem2009 -access +rwc -top tb_otp_controller \
+incdir+../rtl_sources \
+define+POSTSYN_SIM \
../rtl_sources/otp_sim_rom.v \
../rtl_sources/tb_otp_controller.v
