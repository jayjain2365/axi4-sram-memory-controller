`timescale 1ns / 1ps

module tb_axi4_write;

    // --------------------------------
    // 1. Clock and reset
    // --------------------------------

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;


    // --------------------------------
    // 2. AXI4 Write Address Channel
    // --------------------------------

    logic [31:0] awaddr;
    logic [7:0]  awlen;
    logic [2:0]  awsize;
    logic [1:0]  awburst;
    logic        awvalid;
    wire         awready;


    // --------------------------------
    // 3. AXI4 Write Data Channel
    // --------------------------------

    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wlast;
    logic        wvalid;
    wire         wready;


    // --------------------------------
    // 4. AXI4 Write Response Channel
    // --------------------------------

    wire [1:0] bresp;
    wire       bvalid;
    logic      bready;


    // --------------------------------
    // 5. SRAM Interface
    // --------------------------------

    wire        sram_req;
    wire        sram_we;
    wire [7:0]  sram_addr;
    wire [31:0] sram_wdata;
    wire [3:0]  sram_be;

    wire        sram_ready;
    wire        sram_done;
    wire [31:0] sram_rdata;

    wire        mem_en;
    wire        mem_we;
    wire [7:0]  mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire [31:0] mem_rdata;

    integer pass_count = 0;
    integer fail_count = 0;

    integer i;


    // --------------------------------
    // 6. AXI4 Write Slave
    // --------------------------------

    axi4_write_slave DUT (

        .clk            (clk),
        .rst_n          (rst_n),

        .s_axi_awaddr   (awaddr),
        .s_axi_awlen    (awlen),
        .s_axi_awsize   (awsize),
        .s_axi_awburst  (awburst),
        .s_axi_awvalid  (awvalid),
        .s_axi_awready  (awready),

        .s_axi_wdata    (wdata),
        .s_axi_wstrb    (wstrb),
        .s_axi_wlast    (wlast),
        .s_axi_wvalid   (wvalid),
        .s_axi_wready   (wready),

        .s_axi_bresp    (bresp),
        .s_axi_bvalid   (bvalid),
        .s_axi_bready   (bready),

        .sram_req       (sram_req),
        .sram_we        (sram_we),
        .sram_addr      (sram_addr),
        .sram_wdata     (sram_wdata),
        .sram_be        (sram_be),

        .sram_ready     (sram_ready),
        .sram_done      (sram_done)
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
        .wdata     (sram_wdata),
        .be        (sram_be),

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
    // 9. Task: Send Write Address
    // --------------------------------

    task automatic send_aw(
        input logic [31:0] address,
        input logic [7:0] length
    );

        begin

            @(negedge clk);

            awaddr  = address;
            awlen   = length;
            awsize  = 3'b010;
            awburst = 2'b01;
            awvalid = 1'b1;

            // Wait for AW handshake
            do begin
                @(posedge clk);
            end while (awready !== 1'b1);

            @(negedge clk);

            awvalid = 1'b0;

            $display("AW ACCEPTED: Addr=%h LEN=%0d",
                     address, length);

        end

    endtask


    // --------------------------------
    // 10. Task: Send Write Data Beat
    // --------------------------------

    task automatic send_wbeat(
        input logic [31:0] data,
        input logic [3:0]  strobe,
        input logic        last
    );

        begin

            @(negedge clk);

            wdata  = data;
            wstrb  = strobe;
            wlast  = last;
            wvalid = 1'b1;

            // Wait for W handshake
            do begin
                @(posedge clk);
            end while (wready !== 1'b1);

            @(negedge clk);

            wvalid = 1'b0;

            $display("W BEAT SENT: Data=%h STRB=%b LAST=%b",
                     data, strobe, last);

        end

    endtask


    // --------------------------------
    // 11. Task: Check Write Response
    // --------------------------------

    task automatic check_bresp;

        begin

            wait (bvalid === 1'b1);

            // Keep BREADY low to test response backpressure
            repeat (3) @(posedge clk);

            if (bvalid !== 1'b1) begin
                $display("FAIL: BVALID was not held");
                fail_count = fail_count + 1;
            end
            else begin
                $display("PASS: BVALID held during backpressure");
                pass_count = pass_count + 1;
            end

            if (bresp === 2'b00) begin
                $display("PASS: Write response is OKAY");
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: Write response is not OKAY");
                fail_count = fail_count + 1;
            end

            @(negedge clk);
            bready = 1'b1;

            @(posedge clk);

            @(negedge clk);
            bready = 1'b0;

            $display("WRITE RESPONSE ACCEPTED");

        end

    endtask


    // --------------------------------
    // 12. Task: Check SRAM Contents
    // --------------------------------

    task automatic check_mem(
        input integer index,
        input logic [31:0] expected,
        input string test_name
    );

        logic [31:0] actual;

        begin

            actual = SRAM.mem[index];

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
    // 13. Main Test Sequence
    // --------------------------------

    initial begin

        rst_n = 0;

        awaddr  = 0;
        awlen   = 0;
        awsize  = 0;
        awburst = 0;
        awvalid = 0;

        wdata  = 0;
        wstrb  = 0;
        wlast  = 0;
        wvalid = 0;

        bready = 0;

        $display("--------------------------------");
        $display("AXI4 WRITE TEST STARTED");
        $display("--------------------------------");

        repeat (2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);


        // --------------------------------
        // TEST 1: Single Beat Write
        // --------------------------------

        $display("\n--- TEST 1: SINGLE BEAT WRITE ---");

        send_aw(32'h00000000, 8'd0);

        send_wbeat(32'hAABBCCDD, 4'b1111, 1'b1);

        check_bresp();

        check_mem(0, 32'hAABBCCDD,
                  "Single beat write");


        // --------------------------------
        // TEST 2: Four Beat Burst
        // --------------------------------

        $display("\n--- TEST 2: FOUR BEAT BURST ---");

        send_aw(32'h00000014, 8'd3);

        send_wbeat(32'hAAAA5555, 4'b1111, 1'b0);
        send_wbeat(32'hBBBB6666, 4'b1111, 1'b0);
        send_wbeat(32'hCCCC7777, 4'b1111, 1'b0);
        send_wbeat(32'hDDDD8888, 4'b1111, 1'b1);

        check_bresp();

        check_mem(5, 32'hAAAA5555, "Burst beat 1");
        check_mem(6, 32'hBBBB6666, "Burst beat 2");
        check_mem(7, 32'hCCCC7777, "Burst beat 3");
        check_mem(8, 32'hDDDD8888, "Burst beat 4");


        // --------------------------------
        // TEST 3: Sixteen Beat Burst
        // --------------------------------

        $display("\n--- TEST 3: SIXTEEN BEAT BURST ---");

        send_aw(32'h00000040, 8'd15);

        for (i = 0; i < 16; i = i + 1) begin

            send_wbeat(
                32'h10000000 + i,
                4'b1111,
                (i == 15)
            );

        end

        check_bresp();

        for (i = 0; i < 16; i = i + 1) begin

            check_mem(
                16 + i,
                32'h10000000 + i,
                "16-beat burst"
            );

        end


        // --------------------------------
        // TEST 4: Partial Byte Write
        // --------------------------------

        $display("\n--- TEST 4: PARTIAL BYTE WRITE ---");

        // Initial full-word write
        send_aw(32'h00000000, 8'd0);
        send_wbeat(32'hAABBCCDD, 4'b1111, 1'b1);

        check_bresp();

        // Update byte lanes 2 and 0
        send_aw(32'h00000000, 8'd0);
        send_wbeat(32'h11223344, 4'b0101, 1'b1);

        check_bresp();

        check_mem(0, 32'hAA22CC44,
                  "Partial write using WSTRB 0101");


        // --------------------------------
        // Final Summary
        // --------------------------------

        $display("\n================================");
        $display("AXI4 WRITE TEST SUMMARY");
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
