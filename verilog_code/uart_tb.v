`timescale 1ns/1ps

module tb_uart_advanced;
    localparam integer CLKS_PER_BIT = 16;
    localparam integer PARITY_MODE = 1; // 1 = even parity (8E1)
    localparam integer CLK_PERIOD_NS = 10;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg tx_dv = 1'b0;
    reg [7:0] tx_byte = 8'h00;
    wire tx_active;
    wire tx_serial;
    wire tx_done;
    wire rx_dv;
    wire [7:0] rx_byte;
    wire parity_error;
    wire frame_error;


    reg rx_drive_en = 1'b0;
    reg rx_drive_line = 1'b1;
    wire rx_line = rx_drive_en ? rx_drive_line : tx_serial;

    always #(CLK_PERIOD_NS/2) clk = ~clk;

    uart_tx_advanced #(
        .CLKS_PER_BIT(CLKS_PER_BIT), .PARITY_MODE(PARITY_MODE)
    ) u_tx (
        .i_clk(clk), .i_rst(rst), .i_tx_dv(tx_dv), .i_tx_byte(tx_byte),
        .o_tx_active(tx_active), .o_tx_serial(tx_serial), .o_tx_done(tx_done)
    );

    uart_rx_advanced #(
        .CLKS_PER_BIT(CLKS_PER_BIT), .PARITY_MODE(PARITY_MODE)
    ) u_rx (
        .i_clk(clk), .i_rst(rst), .i_rx_serial(rx_line),
        .o_rx_dv(rx_dv), .o_rx_byte(rx_byte),
        .o_parity_error(parity_error), .o_frame_error(frame_error)
    );

    task automatic send_and_check(input [7:0] value);
        begin
            @(negedge clk);
            tx_byte = value;
            tx_dv = 1'b1;
            @(negedge clk);
            tx_dv = 1'b0;

            wait (rx_dv === 1'b1);
            #1;
            if (rx_byte !== value || parity_error !== 1'b0 || frame_error !== 1'b0) begin
                $display("FAIL: data expected=0x%02h got=0x%02h parity_error=%b frame_error=%b",
                         value, rx_byte, parity_error, frame_error);
                $fatal(1);
            end else begin
                $display("PASS: clean 8E1 frame 0x%02h", rx_byte);
            end

            @(negedge clk);
            wait (tx_done === 1'b1);
            @(negedge clk);
        end
    endtask


    task automatic send_raw_frame(
        input [7:0] value,
        input parity_value,
        input stop_value
    );
        integer k;
        begin
            @(negedge clk);
            rx_drive_line = 1'b0; // start
            repeat (CLKS_PER_BIT) @(negedge clk);

            for (k = 0; k < 8; k = k + 1) begin
                rx_drive_line = value[k];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end

            rx_drive_line = parity_value;
            repeat (CLKS_PER_BIT) @(negedge clk);
            rx_drive_line = stop_value;
            repeat (CLKS_PER_BIT) @(negedge clk);
            rx_drive_line = 1'b1;
        end
    endtask

    task automatic check_raw_result(
        input [7:0] expected_byte,
        input expected_parity_error,
        input expected_frame_error
    );
        begin
            wait (rx_dv === 1'b1);
            #1;
            if (rx_byte !== expected_byte ||
                parity_error !== expected_parity_error ||
                frame_error !== expected_frame_error) begin
                $display("FAIL: raw frame expected=0x%02h got=0x%02h parity_error=%b (expected %b) frame_error=%b (expected %b)",
                         expected_byte, rx_byte, parity_error, expected_parity_error,
                         frame_error, expected_frame_error);
                $fatal(1);
            end else begin
                $display("PASS: raw frame 0x%02h parity_error=%b frame_error=%b",
                         rx_byte, parity_error, frame_error);
            end
            @(negedge clk);
        end
    endtask

    task automatic run_raw_case(
        input [7:0] value,
        input parity_value,
        input stop_value,
        input expected_parity_error,
        input expected_frame_error
    );
        begin
            fork
                send_raw_frame(value, parity_value, stop_value);
                check_raw_result(value, expected_parity_error, expected_frame_error);
            join
            
            repeat (CLKS_PER_BIT + 4) @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("uart_advanced.vcd");
        $dumpvars(0, tb_uart_advanced);

        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (4) @(negedge clk);

        
        send_and_check(8'h00);
        send_and_check(8'hA5);
        send_and_check(8'h3C);
        send_and_check(8'hFF);

    
        @(negedge clk);
        rx_drive_en = 1'b1;
        rx_drive_line = 1'b1;

        run_raw_case(8'h3C, ~(^8'h3C), 1'b1, 1'b1, 1'b0);

       
        run_raw_case(8'h96, ^8'h96, 1'b0, 1'b0, 1'b1);

        $display("ALL ADVANCED UART TESTS PASSED");
        $finish;
    end
endmodule
