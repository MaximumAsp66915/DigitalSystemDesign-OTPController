`timescale 1ns/1ps
`include "otp_map.vh"
//`define POST_SYN

`ifdef POSTSYN_SIM
    `include "/home/cad/TECH.D/TSMC180/Verilog/tsmc18.v"
    `include "../synthesis/synout/otp_controller_postsyn.v"
`endif

module tb_otp_controller;
    parameter PERIOD = 10;
    parameter TIMEOUT = 1000;
    integer cycle_count;
    integer error = 0;
    integer i, j, k;
    integer read_en_high_count; // reset test component
    integer expected_read_index; // reset test component - expected OTP read number
    reg [7:0] expected_addr;     // reset test component - expected OTP address
    integer  byte_i;                  // loop var for reassembling otp_rom from bytes
    reg clk = 0;
    reg rst_n;
    reg otp_data_out;
    reg [255:0] otp_rom;
    reg [7:0] otp_rom_bytes [0:31];   // shadow: files are 32 bytes, byte0 = OTP bits[7:0]
   

    wire [7:0]  otp_addr;
    wire        otp_read_en;
    wire        busy;
    wire        done;

    wire [14:0] ro_trim_code;
    wire [15:0] tc1_coeff;
    wire [15:0] tc2_coeff;
    wire [15:0] aging_base;
    wire [1:0]  sku_code;
    wire [5:0]  temp_ro_trim;
    wire [5:0]  rev_id;
    wire [5:0]  cfg_flags;
    wire [19:0] ratio_p0;
    wire [19:0] ratio_p1;
    wire [19:0] ratio_p2;
    wire [19:0] ratio_p3;
    wire [19:0] ratio_p4;
    wire        crc_error;
    wire        oe_mode;
    wire        oe_pol;
    wire        prog_disable_lock;  

    otp_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .otp_data_out(otp_data_out),
        .otp_addr(otp_addr),
        .otp_read_en(otp_read_en),
        .busy(busy),
        .done(done),
        .ro_trim_code(ro_trim_code),
        .tc1_coeff(tc1_coeff),
        .tc2_coeff(tc2_coeff),
        .aging_base(aging_base),
        .sku_code(sku_code),
        .temp_ro_trim(temp_ro_trim),
        .rev_id(rev_id),
        .cfg_flags(cfg_flags),
        .ratio_p0(ratio_p0),
        .ratio_p1(ratio_p1),
        .ratio_p2(ratio_p2),
        .ratio_p3(ratio_p3),
        .ratio_p4(ratio_p4),
        .oe_mode(oe_mode),
        .oe_pol(oe_pol),
        .prog_disable_lock(prog_disable_lock),
        .crc_error(crc_error) // I added this one for crc error. comment this and crc error test section out if it is not implemented
    );

    //================================================================
    // post-synthesis timing annotation
    //================================================================
`ifdef POST_SYN
    initial begin
        $display("============ Post-Synthesis SDF Annotation ============");
        $sdf_annotate(
            "../synthesis/synout/otp_controller_postsyn.sdf",
            dut,
            ,
            ,
            "MAXIMUM"
        );
    end
`endif
    //================================================================
    // end post-synthesis timing annotation
    //================================================================

    // clk generation
    always #(PERIOD/2) clk = ~clk;

    //================================================================
    // rom
    always @(posedge clk)
        if (otp_read_en)
            otp_data_out <= otp_rom[otp_addr];
    //================================================================




    //================================================================
    // capturing waveform
    // initial begin
    //     $dumpfile("postsyn_waveform.vcd");
    //     $dumpvars(0,
    //         clk,
    //         rst_n,
    //         otp_data_out,
    //         otp_addr,
    //         otp_read_en,
    //         busy,
    //         done,
    //         ro_trim_code,
    //         ratio_p0,
    //         ratio_p1,
    //         ratio_p2,
    //         ratio_p3,
    //         ratio_p4
    //     );
    // end
    //================================================================

    // main test section
    initial begin
        // ===============================================================================================
        // Reset and initial read Test
        // ===============================================================================================
        // This part of test has been removed from Reset section. It is available in the further sections.
        /*
        // initial values to rom
        otp_rom = 256'h0; 
        otp_rom[14:0]  = 15'hAAAA; 
        otp_rom[30:15] = 16'h5555; 
        otp_rom[46:31] = 16'h1234; 
        otp_rom[62:47] = 16'hFFFF;
        */
        // enabling reset
        $display("============ Reset Test ============");
        rst_n = 1'b0;
        otp_data_out = 1'b0;
        repeat(5) #PERIOD;

        if (ro_trim_code   !== 0) begin $display("Error on reset: ro_trim_code   = %h", ro_trim_code);   error = error + 1; end
        if (tc1_coeff      !== 0) begin $display("Error on reset: tc1_coeff      = %h", tc1_coeff);      error = error + 1; end
        if (tc2_coeff      !== 0) begin $display("Error on reset: tc2_coeff      = %h", tc2_coeff);      error = error + 1; end
        if (aging_base     !== 0) begin $display("Error on reset: aging_base     = %h", aging_base);     error = error + 1; end
        if (sku_code       !== 0) begin $display("Error on reset: sku_code       = %h", sku_code);       error = error + 1; end
        if (temp_ro_trim   !== 0) begin $display("Error on reset: temp_ro_trim   = %h", temp_ro_trim);   error = error + 1; end
        if (rev_id         !== 0) begin $display("Error on reset: rev_id         = %h", rev_id);         error = error + 1; end
        if (cfg_flags      !== 0) begin $display("Error on reset: cfg_flags      = %h", cfg_flags);      error = error + 1; end
        if (ratio_p0       !== 0) begin $display("Error on reset: ratio_p0       = %h", ratio_p0);       error = error + 1; end
        if (ratio_p1       !== 0) begin $display("Error on reset: ratio_p1       = %h", ratio_p1);       error = error + 1; end
        if (ratio_p2       !== 0) begin $display("Error on reset: ratio_p2       = %h", ratio_p2);       error = error + 1; end
        if (ratio_p3       !== 0) begin $display("Error on reset: ratio_p3       = %h", ratio_p3);       error = error + 1; end
        if (ratio_p4       !== 0) begin $display("Error on reset: ratio_p4       = %h", ratio_p4);       error = error + 1; end
        if (busy           !== 0) begin $display("Error on reset: busy           = %h", busy);           error = error + 1; end
        if (done           !== 0) begin $display("Error on reset: done           = %h", done);           error = error + 1; end
        if (otp_read_en    !== 0) begin $display("Error on reset: otp_read_en    = %h", otp_read_en);    error = error + 1; end
        if (otp_addr       !== 0) begin $display("Error on reset: otp_addr       = %h", otp_addr);       error = error + 1; end

        // releasing reset
        rst_n = 1'b1;
        #PERIOD;

        if (busy !== 1'b1) begin
            $display("ERROR: busy did not go high after reset release");
            error = error + 1;
      
        end
        // waiting untill reading from rom starts
        cycle_count = 0;
        while ((otp_addr !== 8'd0 || otp_read_en !== 1'b1) && cycle_count < TIMEOUT) begin
                #PERIOD;
                cycle_count = cycle_count + 1;
        end

        // Check if we timed out waiting for the read to start
        if (otp_addr !== 8'd0 || otp_read_en !== 1'b1) begin
            $display("ERROR: TIMEOUT! Read never started (addr=0, read_en=1) after %0d cycles.", TIMEOUT);
            error = error + 1;
            $stop;
        end
        else 
            $display("Read started: addr=0, read_en=1");
        
        // checking otp_read_en issues every required address correctly
        cycle_count = 0;
        read_en_high_count = 1; // address 0 was already detected above
        expected_read_index = 1;

        while (done !== 1'b1 && cycle_count < TIMEOUT) begin
            #PERIOD;

            if (otp_read_en === 1'b1) begin
 
                if (expected_read_index < 256)
                    expected_addr = expected_read_index[7:0];
                else
                    expected_addr = `OTP_PATCH0_START + (expected_read_index - 256);

                if (otp_addr !== expected_addr) begin
                    $display(
                        "ERROR: incorrect OTP address sequence: read=%0d expected=%0d got=%0d",
                        expected_read_index,
                        expected_addr,
                        otp_addr
                    );
                    error = error + 1;
                end

                read_en_high_count = read_en_high_count + 1;
                expected_read_index = expected_read_index + 1;
            end

            cycle_count = cycle_count + 1;
        end
	$display("total cycles = %d", cycle_count);
        // verify exact pulse count
        if (read_en_high_count !== 312) begin
            $display("ERROR: otp_read_en pulsed %0d times, expected 312 (256 bank + 56 patch)", read_en_high_count);
            error = error + 1;
        end

        // checking if done rises and busy returns to low
        if (done !== 1'b1) begin
            $display("ERROR: TIMEOUT! done never went high after %0d cycles.", TIMEOUT);
            error = error + 1; 
        end
        #PERIOD;
        if (done !== 1'b0) begin
            $display("ERROR: done did not return to low after one cycle,");
            error = error + 1;
        end
        if(busy !== 1'b0) begin
            $display("ERROR: busy did not return to low after done was asserted");
            error = error + 1;

        end

        /*
        // checking if reading data from rom was successful
        if (ro_trim_code !== 15'hAAAA) begin 
            $display("ERROR: ro_trim_code = %h (expected AAAA)", ro_trim_code); 
            error = error + 1; 
        end
        if (tc1_coeff !== 16'h5555) begin 
            $display("ERROR: tc1_coeff = %h (expected 5555)", tc1_coeff); 
            error = error + 1; 
        end
        if (tc2_coeff !== 16'h1234) begin 
            $display("ERROR: tc2_coeff = %h (expected 1234)", tc2_coeff); 
            error = error + 1; 
        end
        if (aging_base !== 16'hFFFF) begin 
            $display("ERROR: aging_base = %h (expected FFFF)", aging_base); 
            error = error + 1; 
        end
        */
        for(i = 0 ; i < 10 ; i = i + 1) begin 
            #PERIOD;
            if (otp_read_en !== 1'b0) begin
                $display("ERROR: otp_read_en went high again after done.");
                error = error + 1;
            end
        end

        $display("Reset Test completed with %d errors!", error);
        error = 0;
        $display("============ Reset Test Complete ============");

        // ===========================================================================================
        // Correct field extraction Test
        // ===========================================================================================
        $display("============ Field extraction Test ============");

        // rom data will be on otp_golden_image.hex and we will read it here
        $readmemh("otp_golden_image.hex", otp_rom_bytes);
        for (byte_i = 0; byte_i < 32; byte_i = byte_i + 1)
            otp_rom[byte_i*8 +: 8] = otp_rom_bytes[byte_i];
        // toggle reset to start module
        reset_dut();
        #PERIOD;

        wait_for_read();
        #PERIOD;
        #PERIOD;

        // Verify ALL output fields match the source data in otp_rom(from .hex file)
        check_all_outputs(otp_rom[14:0]);

        $display("Field extraction Test completed with %d errors!", error);
        error = 0;
        $display("============ Field extraction Test Complete ============");


        // ===========================================================================================
        // Patch override test
        // ===========================================================================================

        // Note: According to the DRS specification for Test 3, we only verify ID = 0.
        // To fully validate the patch decoder logic for all other field IDs (1, 2, 3, 5, 8-12),
        // additional iterations would be required beyond the scope of this specific test.
        // due to DRS we only check ID = 0.

        $display("============ Patch override Test ============");

        // rom data will be on otp_patch_override.hex and we will read it here
        //$readmemh("otp_patch_override.hex", otp_rom_mem); 
        //otp_rom = otp_rom_mem[0];
        $readmemh("otp_patch_override.hex", otp_rom_bytes);
        for (byte_i = 0; byte_i < 32; byte_i = byte_i + 1)
            otp_rom[byte_i*8 +: 8] = otp_rom_bytes[byte_i];
        // toggle reset to start module
        reset_dut();
        #PERIOD;

        wait_for_read();
        #PERIOD;
        #PERIOD;

        check_all_outputs(otp_rom[215:201]);

        $display("Patch override Test completed with %d errors!", error);
        error = 0;
        $display("============ Patch override Test Complete ============");

        // ===========================================================================================
        // Multiple patches test
        // ===========================================================================================
        $display("============ Multiple patches Test ============");
        // rom data will be on otp_patch_override.hex and we will read it here
        //$readmemh("otp_multipatch_override.hex", otp_rom_mem); 
        //otp_rom = otp_rom_mem[0];
        $readmemh("otp_multipatch_override.hex", otp_rom_bytes);
        for (byte_i = 0; byte_i < 32; byte_i = byte_i + 1)
            otp_rom[byte_i*8 +: 8] = otp_rom_bytes[byte_i];
        // toggle reset to start module
        reset_dut();
        #PERIOD;

        wait_for_read();
        #PERIOD;
        #PERIOD;

        check_all_outputs(otp_rom[243:229]);

        $display("Multiple patches Test completed with %d errors!", error);
        error = 0;

        $display("============ Multiple patches Test Complete ============");

        // ===========================================================================================
        // Invalid patch test
        // ===========================================================================================
        $display("============ Invalid patch Test ============");
        // rom data will be on otp_patch_override.hex and we will read it here
        //$readmemh("otp_invalidpatch_override.hex", otp_rom_mem); 
        //otp_rom = otp_rom_mem[0];
        $readmemh("otp_invalidpatch_override.hex", otp_rom_bytes);
        for (byte_i = 0; byte_i < 32; byte_i = byte_i + 1)
            otp_rom[byte_i*8 +: 8] = otp_rom_bytes[byte_i];
        // toggle reset to start module
        reset_dut();
        #PERIOD;

        wait_for_read();
        #PERIOD;
        #PERIOD;

        check_all_outputs(otp_rom[14:0]);

        $display("Invalid patch Test completed with %d errors!", error);
        error = 0;
        $display("============ Invalid patch Test Complete ============");

        // ===========================================================================================
        // CRC error test
        // ===========================================================================================
        $display("============ CRC error Test ============");
        // rom data will be on otp_crc_error.hex and we will read it here
        //$readmemh("otp_crc_error.hex", otp_rom_mem); 
        //otp_rom = otp_rom_mem[0];
        $readmemh("otp_crc_error.hex", otp_rom_bytes);
        for (byte_i = 0; byte_i < 32; byte_i = byte_i + 1)
            otp_rom[byte_i*8 +: 8] = otp_rom_bytes[byte_i];
        // toggle reset to start module
        reset_dut();
        #PERIOD;

        wait_for_read();
        #PERIOD;
        #PERIOD;

        if (crc_error !== 1'b1) begin
            $display("ERROR: CRC error flag was NOT set!");
            error = error + 1;
        end
        //check_all_outputs(otp_rom[14:0]);
        $display("CRC error Test completed with %d errors!", error);
        error = 0;

        $display("============ CRC error Test Complete ============");

        // =========================================================================================
        $display("============ All Tests Complete ============");
        $finish;

    end


    // =========================================================================
    // tasks
    // =========================================================================

    task wait_for_read;
        begin
            // Wait for the first read pulse (addr=0, read_en=1) with a timeout
            cycle_count = 0;
            while ((otp_addr !== 8'd0 || otp_read_en !== 1'b1) && cycle_count < TIMEOUT) begin
                #PERIOD;
                cycle_count = cycle_count + 1;
            end

            // Check if we timed out waiting for the read to start
            if (otp_addr !== 8'd0 || otp_read_en !== 1'b1) begin
                $display("ERROR: TIMEOUT! Read never started (addr=0, read_en=1) after %0d cycles.", TIMEOUT);
                error = error + 1;
             
            end
            else begin
                $display("Read started: addr=0, read_en=1");
                
                // Wait for DONE with a timeout
                cycle_count = 0;
                while (done !== 1'b1 && cycle_count < TIMEOUT) begin
                    #PERIOD;
                    cycle_count = cycle_count + 1;
                end

                // Check if we timed out waiting for DONE
                if (done !== 1'b1) begin
                    $display("ERROR: TIMEOUT! done never went high after %0d cycles.", TIMEOUT);
                    error = error + 1;
                end
            end
        end
    endtask

    //enable reset
    task reset_dut;
        begin
            rst_n = 1'b0;
            repeat(5) #PERIOD;
            rst_n = 1'b1;
            //#PERIOD;
        end
    endtask


    task check_all_outputs;
        input [14:0] exp_ro_trim;
        begin
            // 1. Check RO_TRIM (uses the input argument for flexibility)
            if (ro_trim_code !== exp_ro_trim)    begin $display("ERROR: ro_trim_code expected %h got %h", exp_ro_trim, ro_trim_code);    error = error + 1; end
            if (tc1_coeff    !== otp_rom[30:15]) begin $display("ERROR: tc1_coeff expected %h got %h", otp_rom[30:15], tc1_coeff);       error = error + 1; end
            if (tc2_coeff    !== otp_rom[46:31]) begin $display("ERROR: tc2_coeff expected %h got %h", otp_rom[46:31], tc2_coeff);       error = error + 1; end
            if (aging_base   !== otp_rom[62:47]) begin $display("ERROR: aging_base expected %h got %h", otp_rom[62:47], aging_base);     error = error + 1; end
            if (sku_code     !== otp_rom[64:63]) begin $display("ERROR: sku_code expected %h got %h", otp_rom[64:63], sku_code);         error = error + 1; end
            if (temp_ro_trim !== otp_rom[70:65]) begin $display("ERROR: temp_ro_trim expected %h got %h", otp_rom[70:65], temp_ro_trim); error = error + 1; end
            if (rev_id       !== otp_rom[76:71]) begin $display("ERROR: rev_id expected %h got %h", otp_rom[76:71], rev_id);             error = error + 1; end
            if (cfg_flags    !== otp_rom[82:77]) begin $display("ERROR: cfg_flags expected %h got %h", otp_rom[82:77], cfg_flags);       error = error + 1; end
            
            // Check Ratios (20-bit slices)
            if (ratio_p0     !== otp_rom[102:83])  begin $display("ERROR: ratio_p0 expected %h got %h", otp_rom[102:83], ratio_p0);  error = error + 1; end
            if (ratio_p1     !== otp_rom[122:103]) begin $display("ERROR: ratio_p1 expected %h got %h", otp_rom[122:103], ratio_p1); error = error + 1; end
            if (ratio_p2     !== otp_rom[142:123]) begin $display("ERROR: ratio_p2 expected %h got %h", otp_rom[142:123], ratio_p2); error = error + 1; end
            if (ratio_p3     !== otp_rom[162:143]) begin $display("ERROR: ratio_p3 expected %h got %h", otp_rom[162:143], ratio_p3); error = error + 1; end
            if (ratio_p4     !== otp_rom[182:163]) begin $display("ERROR: ratio_p4 expected %h got %h", otp_rom[182:163], ratio_p4); error = error + 1; end
            // Check extra flags extracted from CFG_FLAGS
            if (oe_mode !== otp_rom[`OTP_CFG_FLAGS_LSB + 0]) begin $display("ERROR: oe_mode expected %h got %h", otp_rom[`OTP_CFG_FLAGS_LSB + 0], oe_mode); error = error + 1; end
            if (oe_pol  !== otp_rom[`OTP_CFG_FLAGS_LSB + 1]) begin $display("ERROR: oe_pol expected %h got %h", otp_rom[`OTP_CFG_FLAGS_LSB + 1], oe_pol); error = error + 1; end
            if (prog_disable_lock !== otp_rom[`OTP_CFG_FLAGS_LSB + 5]) begin $display("ERROR: prog_disable_lock expected %h got %h", otp_rom[`OTP_CFG_FLAGS_LSB + 5], prog_disable_lock); error = error + 1; end
        end
    endtask

endmodule