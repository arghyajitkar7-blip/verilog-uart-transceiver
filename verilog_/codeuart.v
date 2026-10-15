`timescale 1ns/1ps
module uart_tx_advanced #(
    parameter integer CLKS_PER_BIT = 16,
    parameter integer PARITY_MODE = 1
) (
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_tx_dv,
    input  wire [7:0] i_tx_byte,
    output reg        o_tx_active,
    output reg        o_tx_serial,
    output reg        o_tx_done
);
    localparam integer COUNT_WIDTH = (CLKS_PER_BIT < 2) ? 1 : $clog2(CLKS_PER_BIT);
    localparam [2:0] S_IDLE   = 3'd0,
                     S_START  = 3'd1,
                     S_DATA   = 3'd2,
                     S_PARITY = 3'd3,
                     S_STOP   = 3'd4;

    reg [2:0] state;
    reg [COUNT_WIDTH-1:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] tx_shift;
    reg tx_parity;

    always @(posedge i_clk) begin
        if (i_rst) begin
            state       <= S_IDLE;
            clk_count   <= {COUNT_WIDTH{1'b0}};
            bit_index   <= 3'd0;
            tx_shift    <= 8'd0;
            tx_parity   <= 1'b0;
            o_tx_active <= 1'b0;
            o_tx_serial <= 1'b1;
            o_tx_done   <= 1'b0;
        end else begin
            o_tx_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    o_tx_serial <= 1'b1;
                    o_tx_active <= 1'b0;
                    clk_count   <= {COUNT_WIDTH{1'b0}};
                    if (i_tx_dv) begin
                        tx_shift <= i_tx_byte;
                        if (PARITY_MODE == 1)
                            tx_parity <= ^i_tx_byte; 
                        else if (PARITY_MODE == 2)
                            tx_parity <= ~^i_tx_byte;
                        else
                            tx_parity <= 1'b1;         

                        o_tx_serial <= 1'b0; // start bit
                        o_tx_active <= 1'b1;
                        state       <= S_START;
                    end
                end

                S_START: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count   <= {COUNT_WIDTH{1'b0}};
                        bit_index   <= 3'd0;
                        o_tx_serial <= tx_shift[0];
                        state       <= S_DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= {COUNT_WIDTH{1'b0}};
                        if (bit_index == 3'd7) begin
                            if (PARITY_MODE == 0) begin
                                o_tx_serial <= 1'b1;
                                state       <= S_STOP;
                            end else begin
                                o_tx_serial <= tx_parity;
                                state       <= S_PARITY;
                            end
                        end else begin
                            bit_index   <= bit_index + 1'b1;
                            o_tx_serial <= tx_shift[bit_index + 1'b1];
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_PARITY: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count   <= {COUNT_WIDTH{1'b0}};
                        o_tx_serial <= 1'b1; // stop bit
                        state       <= S_STOP;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count   <= {COUNT_WIDTH{1'b0}};
                        state       <= S_IDLE;
                        o_tx_active <= 1'b0;
                        o_tx_serial <= 1'b1;
                        o_tx_done   <= 1'b1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


module uart_rx_advanced #(
    parameter integer CLKS_PER_BIT = 16,
    parameter integer PARITY_MODE = 1
) (
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_rx_serial,
    output reg        o_rx_dv,
    output reg [7:0]  o_rx_byte,
    output reg        o_parity_error,
    output reg        o_frame_error
);
    localparam integer COUNT_WIDTH = (CLKS_PER_BIT < 2) ? 1 : $clog2(CLKS_PER_BIT);
    localparam [2:0] S_IDLE   = 3'd0,
                     S_START  = 3'd1,
                     S_DATA   = 3'd2,
                     S_PARITY = 3'd3,
                     S_STOP   = 3'd4;

    reg [2:0] state;
    reg [COUNT_WIDTH-1:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] rx_shift;
    reg rx_meta;
    reg rx_sync;
    reg rx_parity_bad;
    reg expected_parity;

    always @(posedge i_clk) begin
        if (i_rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= i_rx_serial;
            rx_sync <= rx_meta;
        end
    end

    always @(*) begin
        if (PARITY_MODE == 1)
            expected_parity = ^rx_shift;  
        else if (PARITY_MODE == 2)
            expected_parity = ~^rx_shift; 
        else
            expected_parity = 1'b0;
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            state          <= S_IDLE;
            clk_count      <= {COUNT_WIDTH{1'b0}};
            bit_index      <= 3'd0;
            rx_shift       <= 8'd0;
            rx_parity_bad  <= 1'b0;
            o_rx_dv        <= 1'b0;
            o_rx_byte      <= 8'd0;
            o_parity_error <= 1'b0;
            o_frame_error  <= 1'b0;
        end else begin
            o_rx_dv        <= 1'b0;
            o_parity_error <= 1'b0;
            o_frame_error  <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_count <= {COUNT_WIDTH{1'b0}};
                    if (rx_sync == 1'b0) begin
                        state         <= S_START;
                        clk_count     <= {COUNT_WIDTH{1'b0}};
                        rx_parity_bad <= 1'b0;
                    end
                end

                S_START: begin
                    if (clk_count == (CLKS_PER_BIT/2)-1) begin
                        clk_count <= {COUNT_WIDTH{1'b0}};
                        if (rx_sync == 1'b0) begin
                            bit_index <= 3'd0;
                            state     <= S_DATA;
                        end else begin
                            state <= S_IDLE; 
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= {COUNT_WIDTH{1'b0}};
                        rx_shift[bit_index] <= rx_sync;
                        if (bit_index == 3'd7) begin
                            if (PARITY_MODE == 0)
                                state <= S_STOP;
                            else
                                state <= S_PARITY;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_PARITY: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count     <= {COUNT_WIDTH{1'b0}};
                        rx_parity_bad <= (rx_sync != expected_parity);
                        state         <= S_STOP;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= {COUNT_WIDTH{1'b0}};
                        state     <= S_IDLE;
                        o_rx_byte <= rx_shift;
                        o_rx_dv   <= 1'b1;       
                        o_frame_error <= (rx_sync == 1'b0);
                        if (PARITY_MODE == 0)
                            o_parity_error <= 1'b0;
                        else
                            o_parity_error <= rx_parity_bad;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
