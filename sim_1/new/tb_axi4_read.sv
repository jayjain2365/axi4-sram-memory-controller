`timescale 1ns / 1ps

module tb_axi4_read;

    // --------------------------------
    // 1. Clock and reset
    // --------------------------------

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;


    // --------------------------------
    // 2. AXI4 Read Address Channel
    // --------------------------------

    logic [31:0] araddr;
    logic [7:0]  arlen;
    logic [2:0]  arsize;
    logic [1:0]  arburst;
    logic        arvalid;
    wire         arready;


    // --------------------------------
    // 3. AXI4 Read Data Channel
    // --------------------------------

    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire        rvalid;
    logic       rready;


    // --------------------------------
    // 4. SRAM Interface
    // --------------------------------

    wire        sram_req;
    wire        sram_we;
    wire [7:0]  sram_addr;

    wire        sram_ready;
    wire        sram_done;
    wire [31:0] sram_rdata;

    wire        mem_en;
    wire        mem_we;
    wire [7:0]  mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire [31:0] mem_rdata;


    // --------------------------------
    // 5. Testbench Variables
    // --------------------------------

    integer pass_count = 0;
    integer fail_count = 0;

    integer i;


    // --------------------------------
    // 6. AXI4 Read Slave
    // --------------------------------

    axi4_read_slave DUT (

        .clk             (clk),
        .rst_n           (rst_n),

        .s_axi_araddr    (araddr),
        .s_axi_arlen     (arlen),
        .s_axi_arsize    (arsize),
        .s_axi_arburst   (arburst),
        .s_axi_arvalid   (arvalid),
        .s_axi_arready   (arready),

        .s_axi_rdata     (rdata),
        .s_axi_rresp     (rresp),
        .s_axi_rlast     (rlast),
        .s_axi_rvalid    (rvalid),
        .s_axi_rready    (rready),

        .sram_req        (sram_req),
        .sram_we         (sram_we),
        .sram_addr       (sram_addr),

        .sram_ready      (sram_ready),
        .sram_done       (sram_done),
        .sram_rdata      (sram_rdata)

    );


    // --------------------------------
    // 7. Existing SRAM Controller
    // --------------------------------

    sram_controller SRAM_CTRL (

        .clk       (clk),
        .rst_n     (rst_n),

        .req       (sram_req),
        .we        (sram_we),
        .addr      (sram_addr),
        .wdata     (32'd0),
        .be        (4'b0000),

        .ready     (sram_ready),
        .done      (sram_done),
        .rdata     (sram_rdata),

        .mem_en    (mem_en),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_be    (mem_be),
        .mem_rdata (mem_rdata)

    );


    // --------------------------------
    // 8. Existing SRAM Memory Model
    // --------------------------------

    sram_256x32_model SRAM (

        .clk       (clk),
        .mem_en    (mem_en),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_be    (mem_be),
        .mem_rdata (mem_rdata)

    );


    // --------------------------------
    // 9. Task: Check Read Data
    // --------------------------------

    task automatic check_data(

        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name

    );

        begin

            if (actual === expected) begin

                $display("PASS: %s | Actual=%h",
                         test_name, actual);

                pass_count = pass_count + 1;

            end

            else begin

                $display("FAIL: %s | Actual=%h Expected=%h",
                         test_name, actual, expected);

                fail_count = fail_count + 1;

            end

        end

    endtask


    // --------------------------------
    // 10. Task: Initialize SRAM
    // --------------------------------

    task automatic initialize_memory;

        begin

            SRAM.mem[0] = 32'hAABBCCDD;

            SRAM.mem[5] = 32'hAAAA5555;
            SRAM.mem[6] = 32'hBBBB6666;
            SRAM.mem[7] = 32'hCCCC7777;
            SRAM.mem[8] = 32'hDDDD8888;

            for (integer j = 0; j < 16; j = j + 1) begin

                SRAM.mem[16+j] = 32'h10000000 + j;

            end

        end

    endtask


    // --------------------------------
    // 11. Task: Send Read Address
    // --------------------------------

    task automatic send_ar(

        input logic [31:0] address,
        input logic [7:0] length

    );

        begin

            @(negedge clk);

            araddr  = address;
            arlen   = length;
            arsize  = 3'b010;
            arburst = 2'b01;
            arvalid = 1'b1;

            // Wait for AR handshake
            do begin
                @(posedge clk);
            end while (arready !== 1'b1);

            @(negedge clk);

            arvalid = 1'b0;

            $display("AR ACCEPTED: Addr=%h LEN=%0d",
                     address, length);

        end

    endtask


    // --------------------------------
    // 12. Task: Receive Read Data Beat
    // --------------------------------

    task automatic receive_rbeat(

        input logic [31:0] expected_data,
        input logic        expected_last,
        input string       test_name

    );

        begin

            // Wait until read data becomes valid
            wait (rvalid === 1'b1);

            // Check data and RLAST before handshake
            check_data(rdata, expected_data, test_name);

            if (rlast === expected_last) begin

                $display("PASS: RLAST = %b", rlast);

                pass_count = pass_count + 1;

            end

            else begin

                $display("FAIL: RLAST | Actual=%b Expected=%b",
                         rlast, expected_last);

                fail_count = fail_count + 1;

            end

            // Accept the read data beat
            @(negedge clk);
            rready = 1'b1;

            @(posedge clk);

            @(negedge clk);
            rready = 1'b0;

        end

    endtask


    // --------------------------------
    // 13. Main Test Sequence
    // --------------------------------

    initial begin

        rst_n = 0;

        araddr  = 0;
        arlen   = 0;
        arsize  = 0;
        arburst = 0;
        arvalid = 0;

        rready = 0;

        $display("--------------------------------");
        $display("AXI4 READ TEST STARTED");
        $display("--------------------------------");

        // Reset
        repeat (2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);

        initialize_memory();


        // --------------------------------
        // TEST 1: SINGLE BEAT READ
        // --------------------------------

        $display("\n--- TEST 1: SINGLE BEAT READ ---");

        send_ar(32'h00000000, 8'd0);

        receive_rbeat(
            32'hAABBCCDD,
            1'b1,
            "Single beat read"
        );


        // --------------------------------
        // TEST 2: FOUR BEAT READ BURST
        // --------------------------------

        $display("\n--- TEST 2: FOUR BEAT READ ---");

        send_ar(32'h00000014, 8'd3);

        receive_rbeat(32'hAAAA5555, 1'b0, "Burst beat 1");
        receive_rbeat(32'hBBBB6666, 1'b0, "Burst beat 2");
        receive_rbeat(32'hCCCC7777, 1'b0, "Burst beat 3");
        receive_rbeat(32'hDDDD8888, 1'b1, "Burst beat 4");


        // --------------------------------
        // TEST 3: SIXTEEN BEAT READ BURST
        // --------------------------------

        $display("\n--- TEST 3: SIXTEEN BEAT READ ---");

        send_ar(32'h00000040, 8'd15);

        for (i = 0; i < 16; i = i + 1) begin

            receive_rbeat(
                32'h10000000 + i,
                (i == 15),
                "16-beat burst"
            );

        end


        // --------------------------------
        // TEST 4: READ BACKPRESSURE
        // --------------------------------

        $display("\n--- TEST 4: READ BACKPRESSURE ---");

        send_ar(32'h00000000, 8'd0);

        // Wait for RVALID
        wait (rvalid === 1'b1);

        // Keep RREADY low for 3 clock cycles
        repeat (3) @(posedge clk);

        if (rvalid === 1'b1) begin

            $display("PASS: RVALID held during backpressure");

            pass_count = pass_count + 1;

        end

        else begin

            $display("FAIL: RVALID dropped during backpressure");

            fail_count = fail_count + 1;

        end

        check_data(
            rdata,
            32'hAABBCCDD,
            "Read data during backpressure"
        );

        // Accept the pending read data
        @(negedge clk);
        rready = 1'b1;

        @(posedge clk);

        @(negedge clk);
        rready = 1'b0;


        // --------------------------------
        // FINAL SUMMARY
        // --------------------------------

        $display("\n================================");
        $display("AXI4 READ TEST SUMMARY");
        $display("PASSED = %0d", pass_count);
        $display("FAILED = %0d", fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $display("================================");

        $finish;

    end

endmodule
