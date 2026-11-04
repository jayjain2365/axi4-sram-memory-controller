module axi4_read_slave(
    input wire clk,
    input wire rst_n,

    // AXI4 Read Address Channel
    input wire [31:0] s_axi_araddr,
    input wire [7:0]  s_axi_arlen,
    input wire [2:0]  s_axi_arsize,
    input wire [1:0]  s_axi_arburst,
    input wire        s_axi_arvalid,
    output wire       s_axi_arready,

    // AXI4 Read Data Channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rlast,
    output wire        s_axi_rvalid,
    input wire         s_axi_rready,

    // SRAM Controller Interface
    output wire        sram_req,
    output wire        sram_we,
    output wire [7:0]  sram_addr,
    input wire         sram_ready,
    input wire         sram_done,
    input wire [31:0]  sram_rdata
);

    localparam IDLE       = 3'b000;
    localparam SRAM_ISSUE = 3'b001;
    localparam SRAM_WAIT  = 3'b010;
    localparam READ_DATA  = 3'b011;

    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    reg [2:0] state;
    reg [31:0] current_addr;
    reg [4:0] beats_remaining;
    reg [31:0] read_data_reg;
    reg read_error;

    wire ar_length_supported = (s_axi_arlen[7:4] == 4'b0000);
    wire ar_size_supported   = (s_axi_arsize == 3'b010);
    wire ar_burst_supported  = (s_axi_arburst == 2'b01);
    wire ar_aligned          = (s_axi_araddr[1:0] == 2'b00);
    wire ar_transaction_supported = ar_length_supported &&
                                    ar_size_supported &&
                                    ar_burst_supported &&
                                    ar_aligned;

    assign s_axi_arready = (state == IDLE);
    assign s_axi_rvalid  = (state == READ_DATA);
    assign s_axi_rdata   = read_data_reg;
    assign s_axi_rresp   = read_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
    // An unsupported read is answered with exactly one error beat.
    assign s_axi_rlast  = (state == READ_DATA) &&
                          (read_error || (beats_remaining == 5'd1));

    assign sram_req  = (state == SRAM_ISSUE);
    assign sram_we   = 1'b0;
    assign sram_addr = current_addr[9:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            current_addr    <= 32'd0;
            beats_remaining <= 5'd0;
            read_data_reg   <= 32'd0;
            read_error      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        current_addr <= s_axi_araddr;
                        if (ar_transaction_supported) begin
                            beats_remaining <= {1'b0, s_axi_arlen[3:0]} + 5'd1;
                            read_error <= 1'b0;
                            state <= SRAM_ISSUE;
                        end else begin
                            // Unsupported reads return one SLVERR beat and
                            // do not access the SRAM.
                            beats_remaining <= 5'd1;
                            read_error <= 1'b1;
                            read_data_reg <= 32'd0;
                            state <= READ_DATA;
                        end
                    end
                end

                SRAM_ISSUE: begin
                    if (sram_ready)
                        state <= SRAM_WAIT;
                end

                SRAM_WAIT: begin
                    if (sram_done) begin
                        read_data_reg <= sram_rdata;
                        state <= READ_DATA;
                    end
                end

                READ_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        if (read_error || (beats_remaining == 5'd1)) begin
                            state <= IDLE;
                            read_error <= 1'b0;
                        end else begin
                            beats_remaining <= beats_remaining - 5'd1;
                            current_addr <= current_addr + 32'd4;
                            state <= SRAM_ISSUE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
