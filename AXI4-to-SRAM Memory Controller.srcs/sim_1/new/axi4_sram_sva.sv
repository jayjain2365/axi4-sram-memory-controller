
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
    |-> (rlast == (read_beats_remaining == 9'd1));
endproperty

assert property (p_rlast_correct)
else $error("SVA FAIL: RLAST asserted at incorrect read beat");
endmodule
