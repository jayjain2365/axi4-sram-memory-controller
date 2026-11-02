module sram_controller (
    input             clk,
    input             rst_n,

    // Request interface
    input             req,
    input             we,
    input      [7:0]  addr,
    input      [31:0] wdata,
    input      [3:0]  be,

    output            ready,
    output reg        done,
    output reg [31:0] rdata,

    // SRAM memory interface
    output reg        mem_en,
    output reg        mem_we,
    output reg [7:0]  mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0]  mem_be,
    input      [31:0] mem_rdata
);

    // FSM state encoding
    localparam IDLE       = 2'b00;
    localparam READ_WAIT  = 2'b01;
    localparam WRITE_DONE = 2'b10;

    reg [1:0] state;

    // Controller is ready only in IDLE
    assign ready = (state == IDLE);

    // State register and sequential operations
    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state <= IDLE;
            done  <= 1'b0;
            rdata <= 32'b0;
        end

        else begin

            done <= 1'b0;

            case (state)

                IDLE: begin

                    if (req && ready) begin

                        if (we)
                            state <= WRITE_DONE;
                        else
                            state <= READ_WAIT;

                    end

                end

                READ_WAIT: begin

                    rdata <= mem_rdata;
                    done  <= 1'b1;
                    state <= IDLE;

                end

                WRITE_DONE: begin

                    done  <= 1'b1;
                    state <= IDLE;

                end

                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end

    // SRAM control signal generation
    always @(*) begin

        mem_en    = 1'b0;
        mem_we    = 1'b0;
        mem_addr  = 8'b0;
        mem_wdata = 32'b0;
        mem_be    = 4'b0;

        if ((state == IDLE) && req && ready) begin

            mem_en    = 1'b1;
            mem_we    = we;
            mem_addr  = addr;
            mem_wdata = wdata;
            mem_be    = be;

        end

    end

endmodule
