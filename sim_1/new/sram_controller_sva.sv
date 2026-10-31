
module sram_controller_sva (

    input logic clk,
    input logic rst_n,

    input logic req,
    input logic we,
    input logic ready,
    input logic done,

    input logic mem_en,
    input logic mem_we

);

    // A1: Memory enable only when a request
    // is accepted by the controller.

    property p_request_acceptance;
        @(posedge clk)
        disable iff (!rst_n)
        mem_en |-> (req && ready);
    endproperty

    assert property (p_request_acceptance)
        else $error("A1 FAILED: Invalid memory request");


    // A2: Accepted request must activate memory.

    property p_memory_enable;
        @(posedge clk)
        disable iff (!rst_n)
        (req && ready) |-> mem_en;
    endproperty

    assert property (p_memory_enable)
        else $error("A2 FAILED: Memory not enabled");


    // A3: Read request must complete
    // at the expected time.

    property p_read_completion;
        @(posedge clk)
        disable iff (!rst_n)
        (req && ready && !we) |=> ##1 done;
    endproperty

    assert property (p_read_completion)
        else $error("A3 FAILED: Read completion timing");


    // A4: Write request must complete
    // at the expected time.

    property p_write_completion;
        @(posedge clk)
        disable iff (!rst_n)
        (req && ready && we) |=> ##1 done;
    endproperty

    assert property (p_write_completion)
        else $error("A4 FAILED: Write completion timing");


    // A5: Done must remain high for
    // exactly one clock cycle.

    property p_done_pulse;
        @(posedge clk)
        disable iff (!rst_n)
        done |=> !done;
    endproperty

    assert property (p_done_pulse)
        else $error("A5 FAILED: Done pulse width");


    // A6: Controller must be ready
    // when operation is completed.

    property p_ready_after_completion;
        @(posedge clk)
        disable iff (!rst_n)
        done |-> ready;
    endproperty

    assert property (p_ready_after_completion)
        else $error("A6 FAILED: Controller not ready");


    // Coverage: Check that reads and writes occur.

    cover property (
        @(posedge clk)
        disable iff (!rst_n)
        req && ready && !we
    );

    cover property (
        @(posedge clk)
        disable iff (!rst_n)
        req && ready && we
    );

endmodule
