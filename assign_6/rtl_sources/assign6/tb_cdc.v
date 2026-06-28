`include "settings.v"

`define POSTSYN_SIM

// ------------------------------------------------------------------
// 1. Conditional inclusion of standard cell library and gate-level netlist
// ------------------------------------------------------------------
`ifdef POSTSYN_SIM
  // Read library and netlist 
  `include "../rtl_sources/tsmc18.v"
  `include "../synthesis/synout/assign6/transmitter_postsyn.v"
  `include "../synthesis/synout/assign6/receiver_postsyn.v"
  `include "../synthesis/synout/assign6/synchronizer_postsyn.v"
`else
  // Read functional description of modules
  `include "../rtl_sources/assign6/metastability_assign.v"
`endif

`timescale 1ps/1fs

// ------------------------------------------------------------------
// To check the behavior of synchronizers

`define WITH_SYNC

`define TRANSPORT_DELAY 491.33
//`define TRANSPORT_DELAY 10.25
//`define TRANSPORT_DELAY 0
// ------------------------------------------------------------------


module tb_cdc;
    // Clock period parameters (can be overridden from command line)
    parameter real TX_CLK_PERIOD = 4002.160;   
    parameter real RX_CLK_PERIOD = 2001.800;
    // parameter real RX_CLK_PERIOD = 2340.300;

    reg  clk_tx, clk_rx;
    wire clk_rx_delayed;
    reg  reset_n;
    wire tx_bit;
    wire rx_bit_sync;
    wire rx_bit_to_rec;
    wire [31:0] rx_data;
    wire data_valid;
    wire tx_data_valid, tx_data_valid_to_rec;

// ------------------------------------------------------------------
// Creating transport delay on all Rx lines
// ------------------------------------------------------------------
   assign #`TRANSPORT_DELAY clk_rx_delayed = clk_rx;


// ------------------------------------------------------------------
// 2. Transmitter instantiation (RTL or gate-level)
// ------------------------------------------------------------------
`ifdef POSTSYN_SIM
    transmitter u_tx_syn (
        .clk_tx (clk_tx),
        .reset_n(reset_n),
        .tx_bit (tx_bit),
        .tx_data_valid (tx_data_valid)
    );
`else
    transmitter tx_inst (
        .clk_tx (clk_tx),
        .reset_n(reset_n),
        .tx_bit (tx_bit),
        .tx_data_valid (tx_data_valid)
    );
`endif

// ------------------------------------------------------------------
// 3. Synchronizer instantiation (conditional)
// ------------------------------------------------------------------
`ifdef WITH_SYNC
    `ifdef POSTSYN_SIM
        synchronizer u_sync_syn1 (
            .clk      (clk_rx_delayed),
            .reset_n  (reset_n),
            .async_in (tx_bit),
            .sync_out (rx_bit_sync)
        );
        synchronizer u_sync_syn2 (
            .clk      (clk_rx_delayed),
            .reset_n  (reset_n),
            .async_in (tx_data_valid),
            .sync_out (tx_data_valid_to_rec_sync)
        );
    `else
        synchronizer sync_inst1 (
            .clk      (clk_rx),
            .reset_n  (reset_n),
            .async_in (tx_bit),
            .sync_out (rx_bit_sync)
        );
        synchronizer sync_inst2 (
            .clk      (clk_rx),
            .reset_n  (reset_n),
            .async_in (tx_data_valid),
            .sync_out (tx_data_valid_to_rec_sync)
        );
    `endif
    assign rx_bit_to_rec = rx_bit_sync;
    assign tx_data_valid_to_rec = tx_data_valid_to_rec_sync;
`else
    assign rx_bit_to_rec = tx_bit;   // no synchronizer – direct connection
    assign tx_data_valid_to_rec = tx_data_valid;
`endif



// ------------------------------------------------------------------
// 4. Receiver instantiation (RTL or gate-level)
// ------------------------------------------------------------------
`ifdef POSTSYN_SIM
    receiver u_rx_syn (
        .clk_rx    (clk_rx_delayed),
        .reset_n   (reset_n),
        .tx_data_valid (tx_data_valid_to_rec),
        .rx_bit    (rx_bit_to_rec),
        .rx_data   (rx_data),
        .data_valid(data_valid)
    );
`else
    receiver rx_inst (
        .clk_rx    (clk_rx),
        .reset_n   (reset_n),
        .tx_data_valid (tx_data_valid_to_rec),
        .rx_bit    (rx_bit_to_rec),
        .rx_data   (rx_data),
        .data_valid(data_valid)
    );
`endif

// ------------------------------------------------------------------
// 5. Clock generation
// ------------------------------------------------------------------
    initial begin
        clk_tx = 0;
        forever #(TX_CLK_PERIOD/2) clk_tx = ~clk_tx;
    end

    initial begin
        clk_rx = 0;
        forever #(RX_CLK_PERIOD/2) clk_rx = ~clk_rx;
    end

// ------------------------------------------------------------------
// 6. Reset and simulation duration
// ------------------------------------------------------------------
    initial begin
        reset_n = 1;
        #1000.000 reset_n = 0;          
        repeat (200) @(negedge clk_rx);
        #10;
        reset_n = 1;          
        //wait (data_valid==1);
        #1800000.000;
        $display("Simulation finished.");
        $finish;
    end

    // ------------------------------------------------------------------
    // 7. Data checking and mismatch reporting
    // ------------------------------------------------------------------
    integer match_cnt = 0;

    always @(posedge clk_rx) begin
        if (data_valid) begin
            if (rx_data != `PATTERN) begin
                $display("ERROR at time %0t: Received 0x%08X, Expected 0x%08X",
                         $time, rx_data, `PATTERN);
            end else begin
                $display("CORRECT at time %0t: Received 0x%08X", $time, rx_data);
                match_cnt = match_cnt + 1;
            end
        end
    end

    final begin
        $display("Total matches: %0d", match_cnt);
    end

    // ------------------------------------------------------------------
    // 8. Waveform dump (VCD)
    // ------------------------------------------------------------------
//    initial begin
//        $dumpfile("tb_cdc.vcd");
//        $dumpvars(0, tb_cdc);
//    end

    // ------------------------------------------------------------------
    // 9. SDF annotation for post‑synthesis simulation
    // ------------------------------------------------------------------
`ifdef POSTSYN_SIM
    initial begin
        $sdf_annotate("../synthesis/synout/assign6/receiver_postsyn.sdf", u_rx_syn, , , "MAXIMUM");
        $sdf_annotate("../synthesis/synout/assign6/transmitter_postsyn.sdf", u_tx_syn, , , "MAXIMUM");
  `ifdef WITH_SYNC
        $sdf_annotate("../synthesis/synout/assign6/synchronizer_postsyn.sdf", u_sync_syn1, , , "MAXIMUM");
        $sdf_annotate("../synthesis/synout/assign6/synchronizer_postsyn.sdf", u_sync_syn2, , , "MAXIMUM");
  `endif 

        $display("SDF annotation attempted (MAXIMUM delays).");
    end
`endif

endmodule