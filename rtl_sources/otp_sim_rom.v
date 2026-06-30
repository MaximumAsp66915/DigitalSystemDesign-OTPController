`default_nettype none
`include "otp_map.vh"
`include "settings.h"

module otp_sim_rom (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] otp_addr,
    input  wire       otp_read_en,
    output reg        otp_data_out
);

    reg [255:0] otp_rom;

    always @(posedge clk or negedge rst_n) begin
        otp_data_out <= 1'b0;
        if (otp_read_en)
            otp_data_out <= otp_rom[otp_addr];
    end

endmodule
