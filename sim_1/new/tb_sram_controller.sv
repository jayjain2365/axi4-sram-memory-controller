`timescale 1ns / 1ps

module tb_sram_controller;

    // --------------------------------
    // 1. Testbench signals
    // --------------------------------

    logic clk;
    logic rst_n;

    logic req;
    logic we;
    logic [7:0] addr;
    logic [31:0] wdata;
    logic [3:0] be;

    wire ready;
    wire done;
    wire [31:0] rdata;

    wire mem_en;
    wire mem_we;
    wire [7:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_be;
    wire [31:0] mem_rdata;

    logic [31:0] read_data;

    integer pass_count = 0;
    integer fail_count = 0;


    // --------------------------------
    // 2. Clock generation
    // --------------------------------

    initial clk = 0;
    always #5 clk = ~clk;


    // --------------------------------
    // 3. DUT: SRAM Controller
    // --------------------------------

    sram_controller DUT (
        .clk       (clk),
        .rst_n     (rst_n),

        .req       (req),
        .we        (we),
        .addr      (addr),
        .wdata     (wdata),
        .be        (be),

        .ready     (ready),
        .done      (done),
        .rdata     (rdata),

        .mem_en    (mem_en),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_be    (mem_be),
        .mem_rdata (mem_rdata)
    );


    // --------------------------------
    // 4. SVA Checker
    // --------------------------------

    sram_controller_sva SVA_CHECKER (
        .clk     (clk),
        .rst_n   (rst_n),

        .req     (req),
        .we      (we),
        .ready   (ready),
        .done    (done),

        .mem_en  (mem_en),
        .mem_we  (mem_we)
    );


    // --------------------------------
    // 5. SRAM Memory Model
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
    // 6. Task: Write operation
    // --------------------------------

    task automatic sram_write(
        input logic [7:0] address,
        input logic [31:0] data,
        input logic [3:0] byte_enable
    );

        begin
            @(negedge clk);
            wait (ready === 1'b1);

            req   = 1'b1;
            we    = 1'b1;
            addr  = address;
            wdata = data;
            be    = byte_enable;

            @(posedge clk);

            @(negedge clk);
            req = 1'b0;

            wait (done === 1'b1);

            $display("WRITE COMPLETED: Addr=%h Data=%h BE=%b",
                     address, data, byte_enable);
        end

    endtask


    // --------------------------------
    // 7. Task: Read operation
    // --------------------------------

    task automatic sram_read(
        input logic [7:0] address,
        output logic [31:0] data
    );

        begin
            @(negedge clk);
            wait (ready === 1'b1);

            req  = 1'b1;
            we   = 1'b0;
            addr = address;
            be   = 4'b0000;

            @(posedge clk);

            @(negedge clk);
            req = 1'b0;

            wait (done === 1'b1);

            data = rdata;

            $display("READ COMPLETED: Addr=%h Data=%h",
                     address, data);
        end

    endtask


    // --------------------------------
    // 8. Task: Compare expected data
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
    // 9. Main test sequence
    // --------------------------------

    initial begin

        // Initialize inputs
        rst_n = 0;

        req   = 0;
        we    = 0;
        addr  = 0;
        wdata = 0;
        be    = 0;

        $display("--------------------------------");
        $display("SRAM CONTROLLER TEST STARTED");
        $display("--------------------------------");

        // Apply reset
        repeat (2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);

        // TEST 1: Check ready after reset
        if (ready === 1'b1) begin
            $display("PASS: Controller ready after reset");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: Controller not ready after reset");
            fail_count = fail_count + 1;
        end


        // TEST 2: Full word write
        sram_write(8'd5, 32'hAABBCCDD, 4'b1111);


        // TEST 3: Full word read
        sram_read(8'd5, read_data);

        check_data(read_data, 32'hAABBCCDD,
                   "Full word read");


        // TEST 4: Partial byte write (0101)
        sram_write(8'd5, 32'h11223344, 4'b0101);


        // TEST 5: Read after partial write
        sram_read(8'd5, read_data);

        check_data(read_data, 32'hAA22CC44,
                   "Partial byte write 0101");


        // TEST 6: Restore original word
        sram_write(8'd5, 32'hAABBCCDD, 4'b1111);


        // TEST 7: Partial byte write (1010)
        sram_write(8'd5, 32'h11223344, 4'b1010);


        // TEST 8: Read after partial write
        sram_read(8'd5, read_data);

        check_data(read_data, 32'h11BB33DD,
                   "Partial byte write 1010");


        // TEST 9: Independent address
        sram_write(8'd10, 32'hDEADBEEF, 4'b1111);

        sram_read(8'd10, read_data);

        check_data(read_data, 32'hDEADBEEF,
                   "Independent address access");


        // --------------------------------
        // TEST 10: REQUEST WHILE BUSY
        // --------------------------------

        $display("\n--- BUSY REQUEST TEST ---");

        // First request: read address 5
        @(negedge clk);
        wait (ready === 1'b1);

        req   = 1'b1;
        we    = 1'b0;
        addr  = 8'd5;
        wdata = 32'h00000000;
        be    = 4'b0000;

        // First request accepted
        @(posedge clk);

        // At this point controller is busy
        @(negedge clk);

        // Present second request while busy
        req   = 1'b1;
        we    = 1'b1;
        addr  = 8'd12;
        wdata = 32'h12345678;
        be    = 4'b1111;

        if (ready === 1'b0) begin
            $display("PASS: Controller is busy; second request is waiting");
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL: Controller unexpectedly ready");
            fail_count = fail_count + 1;
        end

        // Wait until the controller becomes ready.
        // Keep the second request and its payload stable.
        wait (ready === 1'b1);

        // Second request accepted
        @(posedge clk);

        // Remove request after acceptance
        @(negedge clk);
        req = 1'b0;

        // Wait for second write completion
        wait (done === 1'b1);

        $display("Busy request write completed");

        // Verify second write
        sram_read(8'd12, read_data);

        check_data(read_data, 32'h12345678,
                   "Busy request write");


        // --------------------------------
        // TEST 11: BACK-TO-BACK TRANSACTIONS
        // --------------------------------

        $display("\n--- BACK-TO-BACK TEST ---");

        sram_write(8'd20, 32'hAAAA5555, 4'b1111);

        sram_read(8'd20, read_data);

        check_data(read_data, 32'hAAAA5555,
                   "Back-to-back read 1");


        sram_write(8'd21, 32'hDEADBEEF, 4'b1111);

        sram_read(8'd21, read_data);

        check_data(read_data, 32'hDEADBEEF,
                   "Back-to-back read 2");


        sram_write(8'd22, 32'h1234ABCD, 4'b1111);

        sram_read(8'd22, read_data);

        check_data(read_data, 32'h1234ABCD,
                   "Back-to-back read 3");


        // --------------------------------
        // 12. FINAL TEST SUMMARY
        // --------------------------------

        $display("\n================================");
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
