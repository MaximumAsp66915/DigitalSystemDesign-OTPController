`include "settings.v"

module transmitter (
    input  wire       clk_tx,
    input  wire       reset_n,
    output reg        tx_bit,
    output reg        tx_data_valid
);
    reg [5:0]  bit_cnt;
    reg [31:0] tx_out_reg;
    reg        load;
    //assign tx_bit = tx_out_reg[bit_cnt];

    always @(posedge clk_tx or negedge reset_n) begin
        if (!reset_n) begin
            bit_cnt       <= 5'd0;
            tx_data_valid <= 1'b0;
            tx_out_reg    <= 32'd0;
            load          <= 1'b0;
        end 
        else begin
            if (load) begin
                tx_out_reg <= `PATTERN;
                load <= 1'b0;
                tx_data_valid <= 1'b0;
            end else if (bit_cnt <= 6'd31) begin
                load <= 1'b0;
                tx_bit <= tx_out_reg[0];
                tx_out_reg <= tx_out_reg >> 1;
                tx_data_valid <= 1'b1;
                bit_cnt <= bit_cnt + 1;
            end else begin
                load <= 1'b1;
                tx_bit <= tx_out_reg[0];
                tx_out_reg <= tx_out_reg >> 1;
                tx_data_valid <= 1'b1;
                bit_cnt <= 0;
            end
        end
    end
endmodule


module receiver (
    input  wire       clk_rx,
    input  wire       reset_n,
    input  wire       rx_bit,          // already synchronized to clk_rx
    input  wire       tx_data_valid,
    output reg  [31:0] rx_data,
    output reg        data_valid
);
    reg [31:0] shift_reg;
    reg [6:0]  bit_cnt;
    reg rx_bit_1st, rx_bit_2nd, rx_bit_org;
    reg tx_valid_1st, tx_valid_2nd, tx_data_valid_org;
    
    
    always @(posedge clk_rx or negedge reset_n) begin
        if(!reset_n) begin
            rx_bit_1st <= 0;
            rx_bit_2nd <= 0;
            rx_bit_org <= 0;
            tx_valid_1st <= 0;
            tx_valid_2nd <= 0;
            tx_data_valid_org <= 0;
        end else begin 
            rx_bit_1st <= rx_bit;
            rx_bit_2nd <= rx_bit_1st;
            case ({rx_bit_1st,rx_bit_2nd}) 
                2'b00    :   rx_bit_org <= 1'b0;
                2'b11    :   rx_bit_org <= 1'b1;
                default  :   ;
            endcase

            tx_valid_1st <= tx_data_valid;
            tx_valid_2nd <= tx_valid_1st;
            tx_data_valid_org <= tx_valid_1st && tx_valid_2nd;
        end
    end

    always @(posedge clk_rx or negedge reset_n) begin
        if (!reset_n) begin
            shift_reg   <= 32'b0;
            bit_cnt     <= 7'd0;
            rx_data     <= 32'b0;
            data_valid  <= 1'b0;
        end else if (tx_data_valid_org) begin
            if (bit_cnt <= 7'd63) begin
                rx_data       <= ~bit_cnt[0] ? {rx_bit_org, rx_data[31:1]} : rx_data; 
                data_valid    <= 1'b0;
                bit_cnt       <= bit_cnt + 7'd1;
            end else begin
                //rx_data       <= {rx_bit, rx_data[31:1]}; 
                bit_cnt       <= 0;
                data_valid    <= 1'b1;
            end
        end
    end
endmodule

module synchronizer (
    input  wire clk,
    input  wire reset_n,
    input  wire async_in,
    output wire sync_out
);
    reg sync_ff1, sync_ff2;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= async_in;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sync_out = sync_ff2;
endmodule


