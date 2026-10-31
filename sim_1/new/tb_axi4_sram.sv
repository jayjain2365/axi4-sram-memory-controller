`timescale 1ns/1ps

module tb_axi4_sram;

    reg clk;
    reg rst;

    // Write Address Channel
    reg [31:0] awaddr;
    reg [7:0]  awlen;
    reg [2:0]  awsize;
    reg [1:0]  awburst;
    reg        awvalid;
    wire       awready;

    // Write Data Channel
    reg [31:0] wdata;
    reg [3:0]  wstrb;
    reg        wlast;
    reg        wvalid;
    wire       wready;

    // Write Response Channel
    wire [1:0] bresp;
    wire       bvalid;
    reg        bready;

    // Read Address Channel
    reg [31:0] araddr;
    reg [7:0]  arlen;
    reg [2:0]  arsize;
    reg [1:0]  arburst;
    reg        arvalid;
    wire       arready;

    // Read Data Channel
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire        rvalid;
    reg         rready;

    integer pass_count;
    integer fail_count;
    integer i;

    // DUT
    axi4_sram_top DUT (
        .clk(clk),
        .rst(rst),

        .s_axi_awaddr(awaddr),
        .s_axi_awlen(awlen),
        .s_axi_awsize(awsize),
        .s_axi_awburst(awburst),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),

        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),

        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),

        .s_axi_araddr(araddr),
        .s_axi_arlen(arlen),
        .s_axi_arsize(arsize),
        .s_axi_arburst(arburst),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),

        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rlast(rlast),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready)
    );

    // Clock generation: 10 ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------
    // Send AXI write address
    // ------------------------------------------------
    task automatic send_aw(input [31:0] addr,
                           input [7:0] length);
    begin
        @(negedge clk);
        awaddr  = addr;
        awlen   = length;
        awsize  = 3'b010;
        awburst = 2'b01;
        awvalid = 1'b1;

        do begin
            @(posedge clk);
        end while (!awready);

        @(negedge clk);
        awvalid = 1'b0;
    end
    endtask

    // ------------------------------------------------
    // Send one AXI write data beat
    // ------------------------------------------------
    task automatic send_wbeat(input [31:0] data,
                              input [3:0] strb,
                              input last);
    begin
        @(negedge clk);
        wdata  = data;
        wstrb  = strb;
        wlast  = last;
        wvalid = 1'b1;

        do begin
            @(posedge clk);
        end while (!wready);

        @(negedge clk);
        wvalid = 1'b0;
        wlast  = 1'b0;
    end
    endtask

    // ------------------------------------------------
    // Receive AXI write response
    // ------------------------------------------------
    task automatic receive_bresp;
    begin
        bready = 1'b1;

        do begin
            @(posedge clk);
        end while (!bvalid);

        if (bresp == 2'b00) begin
            pass_count = pass_count + 1;
            $display("PASS: Write response OKAY");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Write response = %b", bresp);
        end

        @(negedge clk);
        bready = 1'b0;
    end
    endtask

    // ------------------------------------------------
    // Complete write burst
    // ------------------------------------------------
    task automatic write_burst(input [31:0] addr,
                               input integer beats,
                               input [31:0] seed,
                               input [3:0] strb);
    integer k;
    begin
        send_aw(addr, beats - 1);

        for (k = 0; k < beats; k = k + 1) begin
            send_wbeat(seed + k, strb, (k == beats - 1));
        end

        receive_bresp();
    end
    endtask

    // ------------------------------------------------
    // Send AXI read address
    // ------------------------------------------------
    task automatic send_ar(input [31:0] addr,
                           input [7:0] length);
    begin
        @(negedge clk);
        araddr  = addr;
        arlen   = length;
        arsize  = 3'b010;
        arburst = 2'b01;
        arvalid = 1'b1;

        do begin
            @(posedge clk);
        end while (!arready);

        @(negedge clk);
        arvalid = 1'b0;
    end
    endtask

    // ------------------------------------------------
    // Receive and check read burst
    // ------------------------------------------------
    task automatic read_burst(input [31:0] addr,
                              input integer beats,
                              input [31:0] expected_seed);
    integer k;
    reg [31:0] received_data;
    begin
        send_ar(addr, beats - 1);

        rready = 1'b1;

        for (k = 0; k < beats; k = k + 1) begin

            do begin
                @(posedge clk);
            end while (!rvalid);

            received_data = rdata;

            if (received_data == expected_seed + k) begin
                pass_count = pass_count + 1;
                $display("PASS: Read beat %0d, Data = %h",
                         k, received_data);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: Read beat %0d, Expected = %h, Got = %h",
                         k, expected_seed + k, received_data);
            end

            if (rlast == (k == beats - 1)) begin
                pass_count = pass_count + 1;
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: Incorrect RLAST at beat %0d", k);
            end

            if (rresp != 2'b00) begin
                fail_count = fail_count + 1;
                $display("FAIL: Read response = %b", rresp);
            end

            @(negedge clk);
        end

        rready = 1'b0;
    end
    endtask

    // ------------------------------------------------
    // Main test sequence
    // ------------------------------------------------
    initial begin

        rst = 1'b1;

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

        araddr  = 0;
        arlen   = 0;
        arsize  = 0;
        arburst = 0;
        arvalid = 0;

        rready = 0;

        pass_count = 0;
        fail_count = 0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        repeat (2) @(posedge clk);

        $display("\n==================================");
        $display(" AXI4 SRAM INTEGRATION TEST");
        $display("==================================");

        // TEST 1: Single-beat write and readback
        $display("\nTEST 1: Single-beat transaction");

        write_burst(32'h00000000, 1,
                    32'hAABBCCDD, 4'b1111);

        read_burst(32'h00000000, 1,
                   32'hAABBCCDD);

        // TEST 2: Four-beat write and readback
        $display("\nTEST 2: Four-beat burst");

        write_burst(32'h00000014, 4,
                    32'hAAAA5555, 4'b1111);

        read_burst(32'h00000014, 4,
                   32'hAAAA5555);

        // TEST 3: Partial byte write
        $display("\nTEST 3: Partial byte write");

        write_burst(32'h00000000, 1,
                    32'h11223344, 4'b0101);

        // Expected result:
        // Original = AABBCCDD
        // New data  = 11223344
        // WSTRB     = 0101
        // Result    = AA22CC44

        read_burst(32'h00000000, 1,
                   32'hAA22CC44);

        // TEST 4: Sixteen-beat burst
        $display("\nTEST 4: Sixteen-beat burst");

        write_burst(32'h00000040, 16,
                    32'h10000000, 4'b1111);

        read_burst(32'h00000040, 16,
                   32'h10000000);

        // Final report
        repeat (5) @(posedge clk);

        $display("\n==================================");
        $display("          TEST SUMMARY");
        $display("==================================");
        $display("PASSED = %0d", pass_count);
        $display("FAILED = %0d", fail_count);
        $display("==================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
