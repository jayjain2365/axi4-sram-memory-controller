module axi4_write_slave (
    input wire clk,
    input wire rst_n,

    // AXI4 Write Address Channel
    input wire [31:0] s_axi_awaddr,
    input wire [7:0]  s_axi_awlen,
    input wire [2:0]  s_axi_awsize,
    input wire [1:0]  s_axi_awburst,
    input wire        s_axi_awvalid,
    output wire       s_axi_awready,

    // AXI4 Write Data Channel
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire        s_axi_wlast,
    input wire        s_axi_wvalid,
    output wire       s_axi_wready,

    // AXI4 Write Response Channel
    output wire [1:0] s_axi_bresp,
    output wire       s_axi_bvalid,
    input wire        s_axi_bready,

    // SRAM Controller Interface
    output wire        sram_req,
    output wire        sram_we,
    output wire [7:0]  sram_addr,
    output wire [31:0] sram_wdata,
    output wire [3:0]  sram_be,
    input wire         sram_ready,
    input wire         sram_done
);

    localparam IDLE       = 3'b000;
    localparam WRITE_DATA = 3'b001;
    localparam SRAM_ISSUE = 3'b010;
    localparam SRAM_WAIT  = 3'b011;
    localparam WRITE_RESP = 3'b100;

    localparam [1:0] AXI_RESP_OKAY  = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    reg [2:0] state;
    reg [31:0] current_addr;
    // Nine bits represent 1 through 256 beats (AWLEN + 1).
    reg [8:0] beats_remaining;
    reg [31:0] write_data_reg;
    reg [3:0] write_strb_reg;
    reg write_error;
    reg transaction_invalid;

    wire aw_length_supported = (s_axi_awlen[7:4] == 4'b0000);
    wire aw_size_supported   = (s_axi_awsize == 3'b010);
    wire aw_burst_supported  = (s_axi_awburst == 2'b01);
    wire aw_aligned          = (s_axi_awaddr[1:0] == 2'b00);

    assign s_axi_awready = (state == IDLE);
    assign s_axi_wready  = (state == WRITE_DATA);
    assign s_axi_bvalid  = (state == WRITE_RESP);
    assign s_axi_bresp   = write_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;

    assign sram_req   = (state == SRAM_ISSUE);
    assign sram_we    = 1'b1;
    assign sram_addr  = current_addr[9:2];
    assign sram_wdata = write_data_reg;
    assign sram_be    = write_strb_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= IDLE;
            current_addr        <= 32'd0;
            beats_remaining     <= 9'd0;
            write_data_reg      <= 32'd0;
            write_strb_reg      <= 4'd0;
            write_error         <= 1'b0;
            transaction_invalid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        current_addr <= s_axi_awaddr;
                        // Keep the complete AXI length so an unsupported
                        // burst can still be drained without desynchronizing W.
                        beats_remaining <= {1'b0, s_axi_awlen} + 9'd1;

                        transaction_invalid <= !(aw_length_supported &&
                                                  aw_size_supported &&
                                                  aw_burst_supported &&
                                                  aw_aligned);
                        write_error <= !(aw_length_supported &&
                                         aw_size_supported &&
                                         aw_burst_supported &&
                                         aw_aligned);
                        state <= WRITE_DATA;
                    end
                end

                WRITE_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        // WLAST must agree with the complete AWLEN value.
                        if (s_axi_wlast != (beats_remaining == 9'd1))
                            write_error <= 1'b1;

                        if (transaction_invalid) begin
                            // Drain the complete unsupported write burst,
                            // but never issue writes to the SRAM.
                            if (beats_remaining == 9'd1) begin
                                state <= WRITE_RESP;
                            end else begin
                                beats_remaining <= beats_remaining - 9'd1;
                            end
                        end else begin
                            write_data_reg <= s_axi_wdata;
                            write_strb_reg <= s_axi_wstrb;
                            state <= SRAM_ISSUE;
                        end
                    end
                end

                SRAM_ISSUE: begin
                    if (sram_ready)
                        state <= SRAM_WAIT;
                end

                SRAM_WAIT: begin
                    if (sram_done) begin
                        if (beats_remaining == 9'd1) begin
                            state <= WRITE_RESP;
                        end else begin
                            beats_remaining <= beats_remaining - 9'd1;
                            current_addr <= current_addr + 32'd4;
                            state <= WRITE_DATA;
                        end
                    end
                end

                WRITE_RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        state <= IDLE;
                        transaction_invalid <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
