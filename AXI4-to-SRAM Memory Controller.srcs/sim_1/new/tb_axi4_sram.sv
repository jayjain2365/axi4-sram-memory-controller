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
    // Scoreboard reference memory
    reg [31:0] ref_mem [0:255];
    
    // Track which byte lanes have known expected values
    reg [3:0] ref_valid [0:255];
    
    // Reference write address
    integer ref_addr;
    
    integer sb_lane;
    integer sb_word;
    reg sb_mismatch;
    integer pass_count;
    integer fail_count;
    integer i;
    // =================================================
// SVA CHECKER INSTANCE
// =================================================

axi4_sram_sva SVA_CHECKER (

    .clk(clk),
    .rst(rst),

    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awvalid(awvalid),
    .awready(awready),

    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),

    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arvalid(arvalid),
    .arready(arready),

    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready)

);
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
// SCOREBOARD: Monitor AXI write transactions
// ------------------------------------------------
integer sb_init;
integer monitor_lane;

always @(posedge clk) begin

    if (rst) begin
        ref_addr = 0;

        for (sb_init = 0; sb_init < 256; sb_init = sb_init + 1) begin
            ref_mem[sb_init]   = 32'h00000000;
            ref_valid[sb_init] = 4'b0000;
        end
    end

    else begin

        // Capture accepted write address
        if (awvalid && awready) begin
            ref_addr = awaddr[9:2];
        end

        // Update reference memory on accepted write beat
        if (wvalid && wready) begin

            if (wstrb[0]) begin
                ref_mem[ref_addr][7:0] = wdata[7:0];
                ref_valid[ref_addr][0] = 1'b1;
            end

            if (wstrb[1]) begin
                ref_mem[ref_addr][15:8] = wdata[15:8];
                ref_valid[ref_addr][1] = 1'b1;
            end

            if (wstrb[2]) begin
                ref_mem[ref_addr][23:16] = wdata[23:16];
                ref_valid[ref_addr][2] = 1'b1;
            end

            if (wstrb[3]) begin
                ref_mem[ref_addr][31:24] = wdata[31:24];
                ref_valid[ref_addr][3] = 1'b1;
            end

            // Move to next word for the next burst beat
            ref_addr = ref_addr + 1;

        end
    end
end
// ------------------------------------------------
// SCOREBOARD: Compare actual and expected data
// ------------------------------------------------
task automatic scoreboard_check(
    input [31:0] addr,
    input [31:0] actual_data
);

    integer word_index;
    integer lane;
    reg mismatch;
    reg [3:0] known_bytes;

begin

    word_index = addr[9:2];
    mismatch = 1'b0;
    known_bytes = ref_valid[word_index];

    // Compare only byte lanes initialized by the testbench
    for (lane = 0; lane < 4; lane = lane + 1) begin

        if (known_bytes[lane]) begin

            if (actual_data[lane*8 +: 8] !==
                ref_mem[word_index][lane*8 +: 8]) begin

                mismatch = 1'b1;

            end
        end
    end

    if (known_bytes == 4'b0000) begin

        fail_count = fail_count + 1;
        $display("SCOREBOARD FAIL: No expected data at address %h",
                 addr);

    end
    else if (mismatch) begin

        fail_count = fail_count + 1;

        $display("SCOREBOARD FAIL: Address = %h", addr);
        $display("Expected = %h, Actual = %h",
                 ref_mem[word_index], actual_data);
        $display("Known byte lanes = %b", known_bytes);

    end
    else begin

        pass_count = pass_count + 1;

        $display("SCOREBOARD PASS: Address = %h, Data = %h",
                 addr, actual_data);

    end

end
endtask
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
// Receive write response with backpressure
// ------------------------------------------------
task automatic receive_bresp_with_stall(input integer stall_cycles);

    integer j;
    reg [1:0] saved_bresp;

    begin
        // Master is initially not ready
        bready = 1'b0;

        // Wait until slave produces a response
        do begin
            @(posedge clk);
        end while (!bvalid);

        saved_bresp = bresp;

        $display("BVALID asserted. Starting backpressure test.");

        // Keep BREADY low and check response stability
        for (j = 0; j < stall_cycles; j = j + 1) begin

            @(posedge clk);

            if (bvalid && (bresp === saved_bresp)) begin
                pass_count = pass_count + 1;
                $display("PASS: BVALID and BRESP stable during stall, cycle %0d",
                         j + 1);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: BVALID or BRESP changed during backpressure");
            end

        end

        // Now allow the response handshake
        @(negedge clk);
        bready = 1'b1;

        @(posedge clk);

        if (bvalid && bready) begin
            pass_count = pass_count + 1;
            $display("PASS: Write response handshake completed");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Write response handshake unsuccessful");
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
            scoreboard_check(
                addr + (k * 4),
                received_data
            );
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
    // Read response with backpressure
    // ------------------------------------------------
    task automatic read_with_stall(
        input [31:0] addr,
        input [31:0] expected_data,
        input integer stall_cycles
    );

        integer j;
        reg [31:0] saved_rdata;
        reg [1:0]  saved_rresp;
        reg        saved_rlast;

    begin

        // Send a single-beat read request
        send_ar(addr, 8'd0);

        // Initially, master is not ready
        @(negedge clk);
        rready = 1'b0;

        // Wait until slave asserts RVALID
        do begin
            @(posedge clk);
        end while (!rvalid);

        // Capture response values
        saved_rdata = rdata;
        scoreboard_check(addr, saved_rdata);
        saved_rresp = rresp;
        saved_rlast = rlast;

        $display("RVALID asserted. Starting read backpressure test.");

        // Check response stability during stall
        for (j = 0; j < stall_cycles; j = j + 1) begin

            @(posedge clk);

            if (rvalid &&
                (rdata === saved_rdata) &&
                (rresp === saved_rresp) &&
                (rlast === saved_rlast)) begin

                pass_count = pass_count + 1;

                $display(
                    "PASS: RVALID, RDATA, RRESP and RLAST stable, cycle %0d",
                    j + 1
                );

            end
            else begin

                fail_count = fail_count + 1;

                $display(
                    "FAIL: Read response changed during backpressure, cycle %0d",
                    j + 1
                );

            end

        end

        // Check expected read data
        if (saved_rdata === expected_data) begin
            pass_count = pass_count + 1;
            $display("PASS: Read data = %h", saved_rdata);
        end
        else begin
            fail_count = fail_count + 1;
            $display(
                "FAIL: Expected = %h, Got = %h",
                expected_data, saved_rdata
            );
        end

        // Check response
        if (saved_rresp === 2'b00) begin
            pass_count = pass_count + 1;
            $display("PASS: RRESP = OKAY");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RRESP = %b", saved_rresp);
        end

        // Check final beat
        if (saved_rlast === 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: RLAST = 1");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RLAST was not asserted");
        end

        // Release the read response
        @(negedge clk);
        rready = 1'b1;

        // Wait for response handshake
        @(posedge clk);

        if (rvalid && rready) begin
            pass_count = pass_count + 1;
            $display("PASS: Read response handshake completed");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Read response handshake unsuccessful");
        end

        @(negedge clk);
        rready = 1'b0;

    end
    endtask

    // ------------------------------------------------
    // Simultaneous read and write request test
    // ------------------------------------------------
    task automatic simultaneous_aw_ar_test;

        reg [31:0] received_data;

    begin
        $display("\nTEST 7: Simultaneous AW and AR requests");

        // Present both requests at the same time
        @(negedge clk);

        awaddr  = 32'h000000C0;
        awlen   = 8'd0;
        awsize  = 3'b010;
        awburst = 2'b01;
        awvalid = 1'b1;

        araddr  = 32'h000000C0;
        arlen   = 8'd0;
        arsize  = 3'b010;
        arburst = 2'b01;
        arvalid = 1'b1;

        // Check write priority
        @(posedge clk);

        if (awready && !arready) begin
            pass_count = pass_count + 1;
            $display("PASS: Write request accepted first");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Write priority not observed");
        end

        // Deassert AWVALID, but keep ARVALID pending
        @(negedge clk);
        awvalid = 1'b0;

        // Send write data
        send_wbeat(32'hCAFEBABE, 4'b1111, 1'b1);

        // Complete write response
        receive_bresp();

        // Wait until the pending read request is accepted
        do begin
            @(posedge clk);
        end while (!arready);

        pass_count = pass_count + 1;
        $display("PASS: Pending read request accepted after write");

        @(negedge clk);
        arvalid = 1'b0;

        // Receive read response
        rready = 1'b1;

        do begin
            @(posedge clk);
        end while (!rvalid);

        received_data = rdata;
        scoreboard_check(32'h000000C0, received_data);
        if (received_data === 32'hCAFEBABE) begin
            pass_count = pass_count + 1;
            $display("PASS: Read data = %h", received_data);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Expected CAFEBABE, Got %h",
                     received_data);
        end

        if (rresp == 2'b00 && rlast == 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: Read response OKAY and RLAST asserted");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Incorrect read response or RLAST");
        end

        @(negedge clk);
        rready = 1'b0;

    end
    endtask

    // ------------------------------------------------
    // Data pattern write/read verification
    // ------------------------------------------------
    task automatic data_pattern_test;

        reg [31:0] test_data;
        integer k;

    begin
        $display("\nTEST 8: Data pattern verification");

        // Pattern 1: All zeros
        test_data = 32'h00000000;
        write_burst(32'h00000100, 1, test_data, 4'b1111);
        read_burst(32'h00000100, 1, test_data);

        // Pattern 2: All ones
        test_data = 32'hFFFFFFFF;
        write_burst(32'h00000104, 1, test_data, 4'b1111);
        read_burst(32'h00000104, 1, test_data);

        // Pattern 3: Alternating bits
        test_data = 32'hAAAAAAAA;
        write_burst(32'h00000108, 1, test_data, 4'b1111);
        read_burst(32'h00000108, 1, test_data);

        // Pattern 4: Complementary alternating bits
        test_data = 32'h55555555;
        write_burst(32'h0000010C, 1, test_data, 4'b1111);
        read_burst(32'h0000010C, 1, test_data);

        // Pattern 5: MSB set
        test_data = 32'h80000000;
        write_burst(32'h00000110, 1, test_data, 4'b1111);
        read_burst(32'h00000110, 1, test_data);

        // Pattern 6: LSB set
        test_data = 32'h00000001;
        write_burst(32'h00000114, 1, test_data, 4'b1111);
        read_burst(32'h00000114, 1, test_data);

        // Walking 1: One bit HIGH at a time
        for (k = 0; k < 32; k = k + 1) begin
            test_data = 32'h00000001 << k;

            write_burst(32'h00000120 + (k * 4),
                        1, test_data, 4'b1111);

            read_burst(32'h00000120 + (k * 4),
                       1, test_data);
        end

        // Walking 0: One bit LOW at a time
        for (k = 0; k < 32; k = k + 1) begin
            test_data = ~(32'h00000001 << k);

            write_burst(32'h000001A0 + (k * 4),
                        1, test_data, 4'b1111);

            read_burst(32'h000001A0 + (k * 4),
                       1, test_data);
        end

        // Random data patterns
        for (k = 0; k < 10; k = k + 1) begin
            test_data = $random;

            write_burst(32'h00000220 + (k * 4),
                        1, test_data, 4'b1111);

            read_burst(32'h00000220 + (k * 4),
                       1, test_data);
        end

    end
    endtask

    // ------------------------------------------------
    // Test all 16 WSTRB combinations
    // ------------------------------------------------
    task automatic byte_enable_test;

        integer k;
        reg [3:0] strb;
        reg [31:0] expected_data;

    begin
        $display("\nTEST 9: All WSTRB combinations");

        // Initialize memory location
        write_burst(
            32'h00000300,
            1,
            32'hAABBCCDD,
            4'b1111
        );

        // Test all possible byte-enable combinations
    // Initial expected memory contents
expected_data = 32'hAABBCCDD;

// Test all possible byte-enable combinations
    for (k = 0; k < 16; k = k + 1) begin
    
        strb = k;
    
        // Update expected data cumulatively
        if (strb[0])
            expected_data[7:0] = 8'h44;
    
        if (strb[1])
            expected_data[15:8] = 8'h33;
    
        if (strb[2])
            expected_data[23:16] = 8'h22;
    
        if (strb[3])
            expected_data[31:24] = 8'h11;
    
            $display(
                "Testing WSTRB = %b, Expected = %h",
                strb, expected_data
            );

            // Write new data with selected byte lanes
            write_burst(
                32'h00000300,
                1,
                32'h11223344,
                strb
            );

            // Verify memory contents
            read_burst(
                32'h00000300,
                1,
                expected_data
            );

        end

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
    // TEST 4: Sixteen-beat burst
        $display("\nTEST 4: Sixteen-beat burst");

        write_burst(32'h00000040, 16,
                    32'h10000000, 4'b1111);

        read_burst(32'h00000040, 16,
                   32'h10000000);

// TEST 5: Write response backpressure
$display("\nTEST 5: Write response backpressure");

send_aw(32'h00000080, 8'd0);

send_wbeat(
    32'hDEADBEEF,
    4'b1111,
    1'b1
);

receive_bresp_with_stall(3);

        // Expected result:
        // Original = AABBCCDD
        // New data  = 11223344
        // WSTRB     = 0101
        // Result    = AA22CC44

        read_burst(32'h00000000, 1,
                   32'hAA22CC44);

    
        // TEST 6: Read response backpressure
        $display("\nTEST 6: Read response backpressure");

      read_with_stall(
        32'h00000000,
        32'hAA22CC44,
        3
);
        // TEST 7: Simultaneous read and write requests
        simultaneous_aw_ar_test();
        data_pattern_test(); 
        byte_enable_test();     
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
