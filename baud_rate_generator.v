module baud_rate_generator(
    input clk,
    input rst,
    output tx_enb,
    output rx_enb
	 );

	// Counters for generating TX and RX enable pulses
	reg [12:0] tx_counter;
	reg [9:0]  rx_counter;

	// TX baud rate counter
	always @(posedge clk or posedge rst) begin

		// Reset TX counter
		if(rst)
        tx_counter <= 13'd0;

		// Restart counter after required clock cycles
		else if(tx_counter == 13'd5207)
        tx_counter <= 13'd0;

		// Increment TX counter
		else
        tx_counter <= tx_counter + 1'b1;
	end

	// RX baud rate counter
	always @(posedge clk or posedge rst) begin

		// Reset RX counter
		if(rst)
        rx_counter <= 10'd0;

		// Restart counter after oversampling period
		else if(rx_counter == 10'd324)
        rx_counter <= 10'd0;

		// Increment RX counter
		else
        rx_counter <= rx_counter + 1'b1;
	end

	// Generate one clock enable pulse
    // TX: 9600 baud timing
	assign tx_enb = (tx_counter == 0);

	// RX: 16x oversampling timing
	assign rx_enb = (rx_counter == 0);

endmodule
