# HOW TO — Run This Project in Cadence

This guide covers the three flows for this project: functional (pre-synthesis)
simulation, synthesis, and post-synthesis (gate-level) simulation.

## Folder Structure

```text
Logs/           postsyn_sim_xrun.log, simulation_xrun.log, synthesis_genus.log
                (saved Cadence logs, kept for easy review/debugging)

rtl_sources/    otp_image.mem, otp_map.vh, crc16_ccitt.v, otp_controller.v,
                otp_sim_rom.v, tb_otp_controller.v

simulation/     settings.h
                script/func_sim.tcl
                script/post_syn_sim.tcl

synthesis/      script/lib_scr.tcl
                script/otp_controller_clock_const.tcl
                script/syn_scr.tcl
                synout/otp_controller_postsyn.sdf (genus output, kept for easy review)
                synout/otp_controller_postsyn.v (genus output, kept for easy review)
```

---

## 1. Functional (Pre-Synthesis) Simulation

1. Go to the simulation directory:
   ```bash
   cd simulation
   ```
2. Source the functional sim script:
   ```bash
   source ./script/func_sim.tcl
   ```
3. This launches the Xcelium waveform/console app (SimVision). At the prompt, type:
   ```text
   run
   ```
4. The log for this run is saved as `Logs/simulation_xrun.log`.

---

## 2. Synthesis

1. Go to the synthesis directory:
   ```bash
   cd synthesis
   ```
2. Launch Genus:
   ```bash
   genus
   ```
3. Inside the Genus shell, source the synthesis script:
   ```bash
   source ./script/syn_scr.tcl
   ```
   This script uses `lib_scr.tcl` (library setup) and `otp_controller_clock_const.tcl` (clock constraints) and produces the post-synthesis netlist/SDF in `synout/`:
   * `otp_controller_postsyn.v`
   * `otp_controller_postsyn.sdf`
4. The log for this run is saved as `Logs/synthesis_genus.log`.

---

## 3. Post-Synthesis (Gate-Level) Simulation

1. Go to the simulation directory:
   ```bash
   cd simulation
   ```
2. Source the post-synthesis sim script:
   ```bash
   source ./script/post_syn_sim.tcl
   ```
3. In the Xcelium app that opens, type:
   ```text
   run
   ```
4. The log for this run is saved as `Logs/postsyn_sim_xrun.log`.

> **Note:** You do **not** need to manually set `` `define POSTSYN `` in `tb_otp_controller.v`. The `post_syn_sim.tcl` script handles switching the testbench into post-synthesis mode (netlist + SDF back-annotation) automatically.

---

## 4. How to Check the Output

*   **Verify Simulation Waveforms:** After executing the `run` command in SimVision (during either functional or post-synthesis simulation), visually inspect the generated signal waveforms to confirm the controller behaves as expected.
*   **Check Console and Log Files:** Review the console output for any testbench success/failure messages. If the simulation has closed, you can verify the results by reviewing `simulation/xrun.log`.
*   **Inspect Synthesis Results:** After running synthesis, check the `synthesis/synout/` directory to ensure `otp_controller_postsyn.v` and `otp_controller_postsyn.sdf` were successfully generated. Review `syntheis/genus.logN`(`N` is a number) for any timing violations, area reports, or synthesis warnings.

---

## Quick Reference

| Flow | Directory | Command(s) |
| :--- | :--- | :--- |
| Functional sim | `simulation/` | `source ./script/func_sim.tcl` → `run` |
| Synthesis | `synthesis/` | `genus` → `source ./script/syn_scr.tcl` |
| Post-synthesis sim | `simulation/` | `source ./script/post_syn_sim.tcl` → `run` |
