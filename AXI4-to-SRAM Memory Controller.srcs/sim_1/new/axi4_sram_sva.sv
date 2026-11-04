
module axi4_sram_sva (

    input wire clk,
    input wire rst,

    // Write Address Channel
    input wire [31:0] awaddr,
    input wire [7:0]  awlen,
    input wire [2:0]  awsize,
    input wire [1:0]  awburst,
    input wire        awvalid,
    input wire        awready,

    // Write Data Channel
    input wire [31:0] wdata,
    input wire [3:0]  wstrb,
    input wire        wlast,
    input wire        wvalid,
    input wire        wready,

    // Write Response Channel
    input wire [1:0] bresp,
    input wire       bvalid,
    input wire       bready,

    // Read Address Channel
    input wire [31:0] araddr,
    input wire [7:0]  arlen,
    input wire [2:0]  arsize,
    input wire [1:0]  arburst,
    input wire        arvalid,
    input wire        arready,

    // Read Data Channel
    input wire [31:0] rdata,
    input wire [1:0]  rresp,
    input wire        rlast,
    input wire        rvalid,
    input wire        rready
// Burst beat counters

);
reg [8:0] write_beats_remaining;
reg [8:0] read_beats_remaining;
// Track accepted write burst length
always @(posedge clk) begin

    if (rst) begin
        write_beats_remaining <= 9'd0;
    end
    else begin

        // Capture the number of write beats
        if (awvalid && awready) begin
            write_beats_remaining <= {1'b0, awlen} + 9'd1;
        end

        // Decrement after each accepted write beat
        else if (wvalid && wready) begin
            if (write_beats_remaining != 0)
                write_beats_remaining <= write_beats_remaining - 1'b1;
        end

    end
end
// Track accepted read burst length
always @(posedge clk) begin

    if (rst) begin
        read_beats_remaining <= 9'd0;
    end
    else begin

        // Capture the number of read beats
        if (arvalid && arready) begin
            read_beats_remaining <= {1'b0, arlen} + 9'd1;
        end

        // Decrement after each accepted read beat
        else if (rvalid && rready) begin
            if (read_beats_remaining != 0)
                read_beats_remaining <= read_beats_remaining - 1'b1;
        end

    end
end
// =================================================
// ASSERTION 1: AW CHANNEL STABILITY
// =================================================

property p_aw_stable;
    @(posedge clk)
    disable iff (rst)
    (awvalid && !awready)
    |=> (awvalid &&
         $stable({awaddr, awlen, awsize, awburst}));
endproperty

assert property (p_aw_stable)
else $error("SVA FAIL: AW channel changed during stall");


// =================================================
// ASSERTION 2: W CHANNEL STABILITY
// =================================================

property p_w_stable;
    @(posedge clk)
    disable iff (rst)
    (wvalid && !wready)
    |=> (wvalid &&
         $stable({wdata, wstrb, wlast}));
endproperty

assert property (p_w_stable)
else $error("SVA FAIL: W channel changed during stall");


// =================================================
// ASSERTION 3: B CHANNEL STABILITY
// =================================================

property p_b_stable;
    @(posedge clk)
    disable iff (rst)
    (bvalid && !bready)
    |=> (bvalid && $stable(bresp));
endproperty

assert property (p_b_stable)
else $error("SVA FAIL: B channel changed during stall");


// =================================================
// ASSERTION 4: AR CHANNEL STABILITY
// =================================================

property p_ar_stable;
    @(posedge clk)
    disable iff (rst)
    (arvalid && !arready)
    |=> (arvalid &&
         $stable({araddr, arlen, arsize, arburst}));
endproperty

assert property (p_ar_stable)
else $error("SVA FAIL: AR channel changed during stall");


// =================================================
// ASSERTION 5: R CHANNEL STABILITY
// =================================================

property p_r_stable;
    @(posedge clk)
    disable iff (rst)
    (rvalid && !rready)
    |=> (rvalid &&
         $stable({rdata, rresp, rlast}));
endproperty

assert property (p_r_stable)
else $error("SVA FAIL: R channel changed during stall");
property p_wlast_correct;
    @(posedge clk)
    disable iff (rst)
    (wvalid && wready)
    |-> (wlast == (write_beats_remaining == 9'd1));
endproperty

assert property (p_wlast_correct)
else $error("SVA FAIL: WLAST asserted at incorrect write beat");
property p_rlast_correct;
    @(posedge clk)
    disable iff (rst)
    (rvalid && rready)
    |->
    (rlast == ((rresp == 2'b10) ||
               (read_beats_remaining == 9'd1)));
endproperty

assert property (p_rlast_correct)
else $error("SVA FAIL: RLAST asserted at incorrect read beat");

// =================================================
// ASSERTION 8: BVALID ONLY AFTER ALL WRITE BEATS
// =================================================

property p_bvalid_after_write_complete;
    @(posedge clk)
    disable iff (rst)
    bvalid |-> (write_beats_remaining == 9'd0);
endproperty

assert property (p_bvalid_after_write_complete)
else $error("SVA FAIL: BVALID asserted before all write beats completed");


// =================================================
// ASSERTION 9: RVALID ONLY WITH OUTSTANDING READ BEAT
// =================================================

property p_rvalid_with_outstanding_read;
    @(posedge clk)
    disable iff (rst)
    rvalid |-> (read_beats_remaining != 9'd0);
endproperty

assert property (p_rvalid_with_outstanding_read)
else $error("SVA FAIL: RVALID asserted without an outstanding read beat");


// =================================================
// ASSERTION 10: VALID WRITE RESPONSE CODE
// =================================================

property p_bresp_valid;
    @(posedge clk)
    disable iff (rst)
    bvalid |-> ((bresp == 2'b00) || (bresp == 2'b10));
endproperty

assert property (p_bresp_valid)
else $error("SVA FAIL: Invalid BRESP value");


// =================================================
// ASSERTION 11: VALID READ RESPONSE CODE
// =================================================

property p_rresp_valid;
    @(posedge clk)
    disable iff (rst)
    rvalid |-> (rresp == 2'b00);
endproperty

assert property (p_rresp_valid)
else $error("SVA FAIL: Invalid RRESP value");
// =================================================
// COVERAGE 1: AW CHANNEL STABILITY DURING STALL
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (awvalid && !awready)
    ##1
    (awvalid && $stable({awaddr, awlen, awsize, awburst}))
);

// =================================================
// COVERAGE 2: W CHANNEL STABILITY DURING STALL
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (wvalid && !wready)
    ##1
    (wvalid && $stable({wdata, wstrb, wlast}))
);

// =================================================
// COVERAGE 3: B CHANNEL STABILITY DURING STALL
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (bvalid && !bready)
    ##1
    (bvalid && $stable(bresp))
);

// =================================================
// COVERAGE 4: AR CHANNEL STABILITY DURING STALL
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (arvalid && !arready)
    ##1
    (arvalid && $stable({araddr, arlen, arsize, arburst}))
);

// =================================================
// COVERAGE 5: R CHANNEL STABILITY DURING STALL
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (rvalid && !rready)
    ##1
    (rvalid && $stable({rdata, rresp, rlast}))
);

// =================================================
// COVERAGE 6: CORRECT WLAST
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (wvalid && wready) &&
    (wlast == (write_beats_remaining == 9'd1))
);

// =================================================
// COVERAGE 7: CORRECT RLAST
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    (rvalid && rready) &&
    (rlast == (read_beats_remaining == 9'd1))
);

// =================================================
// COVERAGE 8: BVALID AFTER WRITE COMPLETION
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    bvalid && (write_beats_remaining == 9'd0)
);

// =================================================
// COVERAGE 9: RVALID WITH OUTSTANDING READ
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    rvalid && (read_beats_remaining != 9'd0)
);

// =================================================
// COVERAGE 10: VALID BRESP
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    bvalid &&
    ((bresp == 2'b00) || (bresp == 2'b10))
);

// =================================================
// COVERAGE 11: VALID RRESP
// =================================================

cover property (
    @(posedge clk)
    disable iff (rst)
    rvalid && (rresp == 2'b00)
);
endmodule
