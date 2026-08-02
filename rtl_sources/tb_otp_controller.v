`timescale 1ns/1ps
`include "otp_map.vh"

// ===========================================================================
// tb_otp_controller.v
//
// Self-checking testbench for otp_controller, per DRS section 7:
//   7.1 #1 Reset and initial read
//   7.1 #2 Correct field extraction
//   7.1 #3 Patch override test
//   7.1 #4 Multiple patches (Patch1 wins)
//   7.1 #5 Invalid patch (ignored)
//   7.1 #6 CRC error (optional)
// plus the 7.3 pass/fail table (reset, read sequence, field values, patch
// override, done pulse, no double read).
//
// Note on patch addressing: this TB (and the RTL) place Patch0/Patch1 at
// OTP bits 199-226 / 227-254 (per otp_map.vh), which resolves an internal
// inconsistency in the base DRS text (which literally says 196-223/224-251,
// overlapping the CRC16 field at 183-198).
// ===========================================================================

module tb_otp_controller;

    // -----------------------------------------------------------------
    // Clock / reset
    // -----------------------------------------------------------------
    reg clk = 1'b0;
    reg rst_n;
    always #5 clk = ~clk; // 10 ns period

    // -----------------------------------------------------------------
    // DUT <-> ROM wiring
    // -----------------------------------------------------------------
    wire [7:0] otp_addr;
    wire       otp_read_en;
    wire       otp_data_out;

    wire        busy, done, crc_error;
    wire [14:0] ro_trim_code;
    wire [15:0] tc1_coeff, tc2_coeff, aging_base;
    wire [1:0]  sku_code;
    wire [5:0]  temp_ro_trim, rev_id, cfg_flags;
    wire [19:0] ratio_p0, ratio_p1, ratio_p2, ratio_p3, ratio_p4;
    wire        prog_disable_lock, oe_mode, oe_pol;

    // Default golden image (used for Test 1 and Test 2). Later tests
    // procedurally overwrite u_rom.otp_rom with synthetic images built
    // in this testbench, then re-run the reset sequence -- OTP is
    // "write once, read many" so poking the ROM's storage directly
    // between resets is the right way to model reprogramming a *fresh*
    // (simulated) part, not the real DUT under test.
    otp_sim_rom #(.ROM_FILE("otp_image.mem")) u_rom (
        .clk          (clk),
        .rst_n        (rst_n),
        .otp_addr     (otp_addr),
        .otp_read_en  (otp_read_en),
        .otp_data_out (otp_data_out)
    );

    otp_controller u_dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .otp_data_out      (otp_data_out),
        .otp_addr          (otp_addr),
        .otp_read_en       (otp_read_en),
        .busy              (busy),
        .done              (done),
        .ro_trim_code      (ro_trim_code),
        .tc1_coeff         (tc1_coeff),
        .tc2_coeff         (tc2_coeff),
        .aging_base        (aging_base),
        .sku_code          (sku_code),
        .temp_ro_trim      (temp_ro_trim),
        .rev_id            (rev_id),
        .cfg_flags         (cfg_flags),
        .ratio_p0          (ratio_p0),
        .ratio_p1          (ratio_p1),
        .ratio_p2          (ratio_p2),
        .ratio_p3          (ratio_p3),
        .ratio_p4          (ratio_p4),
        .prog_disable_lock (prog_disable_lock),
        .oe_mode           (oe_mode),
        .oe_pol            (oe_pol),
        .crc_error         (crc_error)
    );

    // -----------------------------------------------------------------
    // Scoreboard
    // -----------------------------------------------------------------
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check(input cond, input [8*96-1:0] msg);
        begin
            if (cond) begin
                pass_cnt = pass_cnt + 1;
                $display("  [PASS] %0s", msg);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("  [FAIL] %0s", msg);
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Image / patch builder helpers
    // -----------------------------------------------------------------

    // One CRC-16/CCITT bit-serial step, identical taps to crc16_ccitt.v
    function automatic [15:0] crc_step(input [15:0] crc, input bit_in);
        reg xor_bit;
        begin
            xor_bit       = bit_in ^ crc[15];
            crc_step[15]  = crc[14] ^ xor_bit;
            crc_step[14]  = crc[13];
            crc_step[13]  = crc[12];
            crc_step[12]  = crc[11] ^ xor_bit;
            crc_step[11]  = crc[10];
            crc_step[10]  = crc[9];
            crc_step[9]   = crc[8];
            crc_step[8]   = crc[7];
            crc_step[7]   = crc[6];
            crc_step[6]   = crc[5];
            crc_step[5]   = crc[4] ^ xor_bit;
            crc_step[4]   = crc[3];
            crc_step[3]   = crc[2];
            crc_step[2]   = crc[1];
            crc_step[1]   = crc[0];
            crc_step[0]   = xor_bit;
        end
    endfunction

    function automatic [15:0] sw_crc16(input [182:0] data183);
        integer i;
        reg [15:0] c;
        begin
            c = 16'hFFFF;
            for (i = 0; i <= 182; i = i + 1)
                c = crc_step(c, data183[i]);
            sw_crc16 = c;
        end
    endfunction

    // Extract an arbitrary field (max 20 bits wide) from a 256-bit image.
    function automatic [19:0] getfield(input [255:0] img, input integer lo, input integer hi);
        integer i;
        reg [19:0] v;
        begin
            v = 20'd0;
            for (i = 0; i <= hi - lo; i = i + 1)
                v[i] = img[lo + i];
            getfield = v;
        end
    endfunction

    // Pack a 28-bit patch record: bit27=valid, 26:22=id, 21:2=data, 1:0=tag
    function automatic [27:0] build_patch(input valid, input [4:0] id, input [19:0] data, input [1:0] tag);
        build_patch = {valid, id, data, tag};
    endfunction

    // Pack a full 256-bit OTP image from field values + two raw patch records.
    // good_crc=1 -> stored CRC matches computed CRC; good_crc=0 -> stored CRC
    // deliberately corrupted (for the CRC-error test).
    function automatic [255:0] build_image(
        input [14:0] ro_trim, input [15:0] tc1, input [15:0] tc2, input [15:0] aging,
        input [1:0]  sku,     input [5:0]  temp_trim, input [5:0] rev, input [5:0] cfg,
        input [19:0] rp0, input [19:0] rp1, input [19:0] rp2, input [19:0] rp3, input [19:0] rp4,
        input [27:0] patch0_raw, input [27:0] patch1_raw,
        input good_crc
    );
        reg [182:0] bank0_bits;
        reg [15:0]  crc_calc;
        reg [255:0] img;
        begin
            bank0_bits[14:0]    = ro_trim;
            bank0_bits[30:15]   = tc1;
            bank0_bits[46:31]   = tc2;
            bank0_bits[62:47]   = aging;
            bank0_bits[64:63]   = sku;
            bank0_bits[70:65]   = temp_trim;
            bank0_bits[76:71]   = rev;
            bank0_bits[82:77]   = cfg;
            bank0_bits[102:83]  = rp0;
            bank0_bits[122:103] = rp1;
            bank0_bits[142:123] = rp2;
            bank0_bits[162:143] = rp3;
            bank0_bits[182:163] = rp4;

            crc_calc = sw_crc16(bank0_bits);

            img              = 256'd0;
            img[182:0]       = bank0_bits;
            img[198:183]     = good_crc ? crc_calc : (crc_calc ^ 16'h0001);
            img[`PATCH0_HI:`PATCH0_LO] = patch0_raw;
            img[`PATCH1_HI:`PATCH1_LO] = patch1_raw;
            img[255]         = 1'b0; // reserved

            build_image = img;
        end
    endfunction

    // -----------------------------------------------------------------
    // Reset / run helpers
    // -----------------------------------------------------------------
    task do_reset;
        begin
            rst_n = 1'b0;
            repeat (4) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    // Waits for `done`, with a watchdog so a hung FSM doesn't stall forever.
    task wait_for_done;
        integer timeout;
        begin
            timeout = 0;
            while (!done && timeout < 1000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            check(done, "watchdog: done asserted before timeout");
        end
    endtask

    // Load `image` into the simulated ROM and re-run the power-on read
    // sequence, returning once `done` has pulsed.
    task load_and_run(input [255:0] image);
        begin
            rst_n = 1'b0;
            @(negedge clk);
            u_rom.otp_rom = image; // poke simulated OTP storage directly
            do_reset;
            wait_for_done;
        end
    endtask

    // -----------------------------------------------------------------
    // Test 1 monitors: busy continuity + address coverage + no-double-read
    // -----------------------------------------------------------------
    reg addr_hit [0:255];
    integer ai;
    reg busy_glitch;
    reg busy_glitch_in_reset; // set if busy is ever seen HIGH while rst_n is low (fault)

    always @(posedge clk) begin
        if (otp_read_en)
            addr_hit[otp_addr] <= 1'b1;
    end

    always @(posedge clk) begin
        if (!rst_n && busy)
            busy_glitch_in_reset <= 1'b1;
    end

    // -----------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------
    reg [255:0] golden_img [0:0];
    reg [255:0] img3, img4, img5a, img5b, img6_good, img6_bad;
    integer i;

    initial begin
        $readmemh("otp_image.mem", golden_img);

        rst_n = 1'b0;
        for (i = 0; i <= 255; i = i + 1) addr_hit[i] = 1'b0;
        busy_glitch_in_reset = 1'b0;

        $display("");
        $display("=====================================================");
        $display(" TEST 1: Reset and initial read");
        $display("=====================================================");

        // Confirm busy/otp_read_en are quiet while still in reset.
        repeat (3) @(posedge clk);
        check(!busy,        "busy is low while rst_n is held low");
        check(!otp_read_en, "otp_read_en is low while rst_n is held low");
        check(!busy_glitch_in_reset, "no busy glitch observed during reset");

        @(negedge clk);
        rst_n = 1'b1;
        $display("  (rst_n released)");

        // busy should assert within a couple of cycles of release
        i = 0;
        while (!busy && i < 5) begin
            @(posedge clk);
            i = i + 1;
        end
        check(busy, "busy asserts shortly after reset release");

        // Track continuous busy until done, flag any glitch
        busy_glitch = 1'b0;
        while (!done) begin
            @(posedge clk);
            if (!busy && !done) busy_glitch = 1'b1;
        end
        check(!busy_glitch, "busy stays asserted continuously until done");
        check(done,         "done pulses after load sequence");

        // done should be exactly one cycle
        @(posedge clk);
        check(!done, "done deasserts one cycle after asserting (single-cycle pulse)");
        check(!busy, "busy is low immediately after done");

        // Address coverage: every OTP address 0..255 should have been read
        // at least once (covers Bank0 sweep + Patch0/Patch1 sweep, since
        // the patch range 199-254 is a subset of 0-255).
        begin : addr_cov
            integer missing;
            missing = 0;
            for (ai = 0; ai <= 255; ai = ai + 1)
                if (!addr_hit[ai]) missing = missing + 1;
            check(missing == 0, "otp_read_en swept every address 0..255 at least once");
        end

        // No double read: after done, no further reads until next reset
        begin : no_dbl_read
            integer extra_reads;
            extra_reads = 0;
            repeat (20) begin
                @(posedge clk);
                if (otp_read_en) extra_reads = extra_reads + 1;
            end
            check(extra_reads == 0, "no further OTP reads occur after done (until next reset)");
        end

        $display("");
        $display("=====================================================");
        $display(" TEST 2: Correct field extraction (golden image, no valid patches)");
        $display("=====================================================");
        check(ro_trim_code === getfield(golden_img[0], 0, 14),
              "T2: RO_TRIM_CODE matches golden image");
        check(tc1_coeff === getfield(golden_img[0], 15, 30),
              "T2: TC1_COEFF matches golden image");
        check(tc2_coeff === getfield(golden_img[0], 31, 46),
              "T2: TC2_COEFF matches golden image");
        check(aging_base === getfield(golden_img[0], 47, 62),
              "T2: AGING_BASE matches golden image");
        check(sku_code === getfield(golden_img[0], 63, 64),
              "T2: SKU_CODE matches golden image");
        check(temp_ro_trim === getfield(golden_img[0], 65, 70),
              "T2: TEMP_RO_TRIM matches golden image");
        check(rev_id === getfield(golden_img[0], 71, 76),
              "T2: REV_ID matches golden image");
        check(cfg_flags === getfield(golden_img[0], 77, 82),
              "T2: CFG_FLAGS matches golden image");
        check(ratio_p0 === getfield(golden_img[0], 83, 102),
              "T2: RATIO_P0 matches golden image");
        check(ratio_p1 === getfield(golden_img[0], 103, 122),
              "T2: RATIO_P1 matches golden image");
        check(ratio_p2 === getfield(golden_img[0], 123, 142),
              "T2: RATIO_P2 matches golden image");
        check(ratio_p3 === getfield(golden_img[0], 143, 162),
              "T2: RATIO_P3 matches golden image");
        check(ratio_p4 === getfield(golden_img[0], 163, 182),
              "T2: RATIO_P4 matches golden image");

        // ----------------------------------------------------------------
        // TEST 3: Patch override -- Patch0 valid, targets RO_TRIM_CODE
        // ----------------------------------------------------------------
        $display("");
        $display("=====================================================");
        $display(" TEST 3: Patch override (Patch0 overrides RO_TRIM_CODE)");
        $display("=====================================================");
        img3 = build_image(
            15'h1234, 16'hABCD, 16'h0F0F, 16'h8000,
            2'b01, 6'h1A, 6'h05, 6'h02,
            20'h11111, 20'h22222, 20'h33333, 20'h44444, 20'h55555,
            build_patch(1'b1, `PID_RO_TRIM, 20'h05555, `PATCH_TAG_VAL), // valid patch0 -> RO_TRIM
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),                     // patch1 invalid
            1'b1
        );
        load_and_run(img3);
        check(ro_trim_code === 15'h5555, "T3: RO_TRIM_CODE overridden by valid Patch0");
        check(tc1_coeff === 16'hABCD,    "T3: TC1_COEFF unaffected by patch (Bank0 value retained)");
        check(cfg_flags === 6'h02,       "T3: CFG_FLAGS unaffected by patch (Bank0 value retained)");
        check(!crc_error,                "T3: CRC valid for this image");

        // ----------------------------------------------------------------
        // TEST 4: Multiple patches targeting the same field -> Patch1 wins
        // ----------------------------------------------------------------
        $display("");
        $display("=====================================================");
        $display(" TEST 4: Multiple patches on same field (Patch1 precedence)");
        $display("=====================================================");
        img4 = build_image(
            15'h1234, 16'hABCD, 16'h0F0F, 16'h8000,
            2'b01, 6'h1A, 6'h05, 6'h02,
            20'h11111, 20'h22222, 20'h33333, 20'h44444, 20'h55555,
            build_patch(1'b1, `PID_RO_TRIM, 20'h0AAAA, `PATCH_TAG_VAL), // patch0 -> 0x2AAA (masked 15b)
            build_patch(1'b1, `PID_RO_TRIM, 20'h01111, `PATCH_TAG_VAL), // patch1 -> 0x1111 (should win)
            1'b1
        );
        load_and_run(img4);
        check(ro_trim_code === 15'h1111, "T4: Patch1 overrides Patch0 on the same field");
        check(!crc_error,                "T4: CRC valid for this image");

        // ----------------------------------------------------------------
        // TEST 5: Invalid patches -- ignored (valid=0, and tag mismatch)
        // ----------------------------------------------------------------
        $display("");
        $display("=====================================================");
        $display(" TEST 5: Invalid patch is ignored");
        $display("=====================================================");
        img5a = build_image(
            15'h1234, 16'hABCD, 16'h0F0F, 16'h8000,
            2'b01, 6'h1A, 6'h05, 6'h02,
            20'h11111, 20'h22222, 20'h33333, 20'h44444, 20'h55555,
            build_patch(1'b0, `PID_RO_TRIM, 20'h05555, `PATCH_TAG_VAL), // valid_bit=0
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),
            1'b1
        );
        load_and_run(img5a);
        check(ro_trim_code === 15'h1234, "T5a: PATCH_VALID=0 is ignored, Bank0 value retained");

        img5b = build_image(
            15'h1234, 16'hABCD, 16'h0F0F, 16'h8000,
            2'b01, 6'h1A, 6'h05, 6'h02,
            20'h11111, 20'h22222, 20'h33333, 20'h44444, 20'h55555,
            build_patch(1'b1, `PID_RO_TRIM, 20'h05555, 2'b01), // valid_bit=1 but wrong tag
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),
            1'b1
        );
        load_and_run(img5b);
        check(ro_trim_code === 15'h1234, "T5b: PATCH_TAG mismatch is ignored, Bank0 value retained");

        // ----------------------------------------------------------------
        // TEST 6: CRC error detection (optional per DRS 6.5 / 7.1 #6)
        // ----------------------------------------------------------------
        $display("");
        $display("=====================================================");
        $display(" TEST 6: CRC error detection");
        $display("=====================================================");
        img6_good = build_image(
            15'h1234, 16'hABCD, 16'h0F0F, 16'h8000,
            2'b01, 6'h1A, 6'h05, 6'h02,
            20'h11111, 20'h22222, 20'h33333, 20'h44444, 20'h55555,
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),
            1'b1
        );
        load_and_run(img6_good);
        check(!crc_error, "T6a: crc_error is low when stored CRC matches computed CRC");

        img6_bad = build_image(
            15'h1234, 16'hABCD, 16'h0F0F, 16'h8000,
            2'b01, 6'h1A, 6'h05, 6'h02,
            20'h11111, 20'h22222, 20'h33333, 20'h44444, 20'h55555,
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),
            build_patch(1'b0, 5'd0, 20'd0, 2'b00),
            1'b0   // force stored CRC to mismatch
        );
        load_and_run(img6_bad);
        check(crc_error, "T6b: crc_error is high when stored CRC does not match computed CRC");

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("");
        $display("=====================================================");
        $display(" SUMMARY: %0d PASSED, %0d FAILED (of %0d checks)", pass_cnt, fail_cnt, pass_cnt + fail_cnt);
        $display("=====================================================");
        if (fail_cnt == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: FAILURES PRESENT -- see [FAIL] lines above");

        $finish;
    end

endmodule
