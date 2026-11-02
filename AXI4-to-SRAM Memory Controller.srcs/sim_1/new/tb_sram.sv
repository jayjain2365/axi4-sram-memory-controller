`timescale 1ns / 1ps

module tb_sram;

    // Testbench signals
    logic clk;
    logic mem_en;
    logic mem_we;

    logic [7:0]  mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_be;

    wire [31:0] mem_rdata;

    integer pass_count = 0;
    integer fail_count = 0;

    // DUT: Verilog SRAM model
    sram_256x32_model DUT (
        .clk       (clk),
        .mem_en    (mem_en),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_be    (mem_be),
        .mem_rdata (mem_rdata)
    );

    // Clock generation: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;


    // ---------------------------------
    // TASK 1: SRAM WRITE
    // ---------------------------------

    task automatic sram_write(
        input logic [7:0]  addr,
        input logic [31:0] data,
        input logic [3:0]  byte_en
    );

        @(negedge clk);

        mem_en    = 1'b1;
        mem_we    = 1'b1;
        mem_addr  = addr;
        mem_wdata = data;
        mem_be    = byte_en;

        @(posedge clk);
        #1;

        mem_en = 1'b0;

    endtask


    // ---------------------------------
    // TASK 2: SRAM READ
    // ---------------------------------

    task automatic sram_read(
        input logic [7:0] addr,
        output logic [31:0] data
    );

        @(negedge clk);

        mem_en   = 1'b1;
        mem_we   = 1'b0;
        mem_addr = addr;
        mem_be   = 4'b0000;

        @(posedge clk);
        #1;

        data = mem_rdata;

        mem_en = 1'b0;

    endtask


    // ---------------------------------
    // TASK 3: CHECK EXPECTED DATA
    // ---------------------------------

    task automatic check_data(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name
    );

        if (actual === expected) begin
            $display("PASS: %s | Actual = %h",
                     test_name, actual);
            pass_count++;
        end
        else begin
            $display("FAIL: %s | Actual = %h | Expected = %h",
                     test_name, actual, expected);
            fail_count++;
        end

    endtask


    // ---------------------------------
    // MAIN TEST SEQUENCE
    // ---------------------------------

    logic [31:0] read_data;

    initial begin

        mem_en    = 0;
        mem_we    = 0;
        mem_addr  = 0;
        mem_wdata = 0;
        mem_be    = 0;

        // TEST 1: Full-word write
        sram_write(8'd5, 32'hAABBCCDD, 4'b1111);

        // TEST 2: Full-word read
        sram_read(8'd5, read_data);
        check_data(read_data, 32'hAABBCCDD,
                   "Full word read/write");


        // TEST 3: Partial byte write
        sram_write(8'd5, 32'h11223344, 4'b0101);

        // TEST 4: Read after partial write
        sram_read(8'd5, read_data);
        check_data(read_data, 32'hAA22CC44,
                   "Partial byte write");


        // TEST 5: Another independent address
        sram_write(8'd10, 32'hDEADBEEF, 4'b1111);

        sram_read(8'd10, read_data);
        check_data(read_data, 32'hDEADBEEF,
                   "Independent address access");


        // TEST SUMMARY
        $display("--------------------------------");
        $display("SRAM VERIFICATION SUMMARY");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("--------------------------------");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;

    end

endmodule
