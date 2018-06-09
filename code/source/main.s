

@ Code section
.section .text

@ Game board boundaries
leftBound = 520
rightBound = 1080
topBound = 120
lowerBound = 900

@ Window parameters
windowX = 500
windowY = 100
windowWidth = 600
windowHeight = 800

@ Brick parameters
bPerRow = 10			@ # of bricks per row
numRows = 3			@ Number of rows of bricks
brickWidth = 40
brickHeight = 20
brickSize = 24			@ Size of an individual brick in memory
brickSpacing = 15		@ Distance (in pixels) between bricks

brickStartX = leftBound + 12
brickStartY = topBound + 60

@ Paddle starting parameters
padWidth = 100
padHeight = 30
padX = windowX + windowWidth/2 - padWidth/2
padY = lowerBound - 100

@ Ball starting parameters
ballWidth = 15
ballX = padX + padWidth/2 - ballWidth/2
ballY = padY - ballWidth

@ Score and lives x coordinates
onesDigX = 600
tensDigX = onesDigX - 50
livesX = 1000

.global main
main:
	@ Initialize frame buffer
	ldr	r0, =frameBufferInfo
	bl	initFbInfo
	
	
	@ Initialize SNES controller
	bl	initSNES
	.global menu  //select goes back to menu, start to reset game
menu:
	bl	drawMenu
	bl 	menuControl

	@ Initialize game
	bl	initGame
	

looptop:

	@ Check for user input
	bl	getInput
	cmp	r0, #0
	blne	processInput

	mov	r0, #2000		// Change to adjust game speed
	bl	delayMicroseconds

	b	looptop

	haltLoop$:
		b	haltLoop$

@ Sets the game to initial conditions (position of objects, # of lives, etc.)
initGame:
	push	{lr}

	@ Reset lives and score to 0*

	cmp		r0, #0			// if menuControl returns 0 in r0 then... 
	bne		haltLoop$		// ... quit game

	@ Draws a black screen for the background
	ldr	r0, =background
	bl	drawImage

	@ Initializes and draws bricks
	bl	initBricks
	bl	resetBricks
	bl	drawBricks

	@ Center paddle in middle of window
	ldr	r0, =paddle
	mov	r1, #padX
	str	r1, [r0]	// Store X coordinate

	mov	r1, #padY
	str	r1, [r0, #4]	// Store Y coordinate

	bl	drawRect	// Draw paddle at initial coordinates

	@ Draws starting location of ball
	ldr	r0, =ball
	mov	r1, #ballX
	str	r1, [r0]	// Store X coord

	mov	r1, #ballY
	str	r1, [r0, #4]	// Store Y coordinate
	bl	drawImage

	pop	{pc}
	

drawScore:
	push	{r4, r5, lr}

	score	.req	r4

	@ Load current score
	ldr	r0, =score
	ldr	score, [r0]
	
	@ Check the tens digit of the score
	mov	r1, #10
	udiv	r2, score, r1	@ r2 = score/10

	@ Load address of image for digit
	ldr	r5, =digArray		@ r5 = base address of digit images array
	ldr	r0, [r3, r2, lsl #2]	@ r0 = address of correct image
	
	@ Set x coordinate for digit
	mov	r2, #tensDigX
	str	r2, [r0]

	@ Draw digit
	bl	drawImage

	pop	{r4, r5, pc}
	

//----------------------------------------------------------------------------
//Returns the bit at a given index of a 16-bit integer
//Args:
//r0 - the number
//r1 - index of bit to get value of
//Return:
//r1 - the desired bit

.globl      getBit
getBit:
    mov     r2, #1          // r2 = b(...00001)
sub r1, #1
    mov     r2, r2, lsl r1  // left shift r2 by r1
    and     r1, r0, r2      // r1: AND r0 with r2 to select only desired bit
    bx      lr              // return

@ Receives pressed button from SNES controller and updates the game state appropriately.
@ r0 - number of the button pressed
processInput:
	push	{r4, r5, lr}

	mov	r4, r0		// Save pressed buttons to r4

// Restart game

	@ Check if A is pressed
	mov	r0, r4
	mov	r1, #9
	bl	getBit

	cmp	r1, #0
	moveq	r5, #1		// Set speed flag if A is pressed
	movne	r5, #0

	@ Check if left joypad is pressed
	mov	r0, r4
	mov	r1, #7
	bl	getBit

	cmp	r1, #0
	moveq	r0, #7
	moveq	r1, r5
	bleq	movePaddle

	@ Check if right joypad is pressed
	mov	r0, r4
	mov	r1, #8
	bl	getBit

	cmp	r1, #0
	moveq	r0, #8
	moveq	r1, r5
	bleq	movePaddle

	@ Check if Start is pressed
	mov	r0, r4
	mov	r1, #4
	bl	getBit
	cmp	r1, #0		// If Start is pressed, reset game
	bleq	initGame

	@ Check if Select is pressed
	mov	r0, r4
	mov	r1, #3
	
	@ Check if B is pressed

	mov 	r0, r4
	mov 	r1, #1
	bl 	getBit

	cmp 	r1, #0
	bleq	launchBall
// Return to menu if so


	pop	{r4, r5, pc}

@ Moves paddle left or right based on the joypad button pressed
@ * Update later to support holding down A to speed up
@ r0 - number of button pressed (7 for left, 8 for right)
@ r1 - flag if A is pressed (1 if pressed, 0 if not)
movePaddle:
	push	{r4, r5, r6, r7, r8, lr}

	cmp	r1, #1		@ Check if A button was pressed
	moveq	r8, #4		@ If A was pressed, set speed higher
	movne	r8, #1

	mov	r4, r0		@ r4 = button pressed
	ldr	r0, =paddle	@ r0 = base address of paddle
	ldr	r5, [r0]	@ r5 = original x-coordinate of paddle

	bl	clearObj	@ Clear paddle from original location

	ldr	r0, =paddle	@ r0 = base address of paddle+

	@ Check if moving left (left pad pressed)
	cmp	r4, #7
	beq	leftmov

	@ Otherwise the paddle is moving right
	@ Check if the paddle is already at the right boundary	
	mov	r6, #rightBound
	ldr	r7, [r0, #8]	@ r7 = width of paddle
	add	r7, r5		@ r7 = x coordinate of right end of paddle

	@ If the paddle's right end is not at the boundary, move right
	cmp	r7, r6		
	addlt	r5, r8
	strlt	r5, [r0]
	bl	drawRect	@ Redraw the moved paddle
	b	end1

leftmov:
	@ Check if new coordinate is out of bounds on left
	mov	r6, #leftBound
	cmp	r5, r6	
	subgt	r5, r8		@ If not out of bounds, move left
	strgt	r5, [r0]	@ Store new x-coordinate
	bl	drawRect	@ Redraw the moved paddle
end1:
	pop	{r4, r5, r6, r7, r8, pc}
launchBall:

	push {r5, r6, r7, lr}
	
	ldr	r0, =ball	@ r0 = base address of ball
	bl clearObj
	
	ldr	r0, =ball	@ r0 = base address of ball	
	
	@ Increment y- coordinate whenever B is pressed
	ldr	r6, [r0, #4]	@ load y- coordinate of the ball
	sub	r6, #1
	str	r6, [r0, #4]
	
	@ Check if the paddle is already at the right boundary	
	ldr	r5, [r0]
	mov	r6, #rightBound
	ldr	r7, [r0, #8]	@ r7 = width of ball
	add	r7, r7, r5	@ r7 = x coordinate of right end of ball

	@ If the balls's right end is not at the boundary, move right
	cmp	r7, r6		
	addlt	r5, #1
	str	r5, [r0]
	bllt	drawImage	@ Redraw the moved ball

	mov	r0, #10000		// Slight delay while progressing the ball
	bl	delayMicroseconds
	
	@	check for right bound
	ldr	r0, =ball	@ r0 = base address of ball	
	mov	r6, #rightBound
	ldr	r7, [r0, #8]	@ r7 = width of ball
	ldr	r5, [r0]
	add	r7, r7, r5	@ r7 = x coordinate of right end of ball
	cmp	r7, r6
	blt	launchBall
end2:
	pop {r5, r6, r7, pc}

@ Sets the health of all the bricks to full.
resetBricks:
	ldr	r0, =bricks
	mov	r1, #3		// Health counter
	mov	r2, #bPerRow	// Counter for # of bricks in a row

outer2:	@ Outer loop runs once for each row of breaks

inner2: @ Inner loop runs once for each brick in a row
	str	r1, [r0, #20]	// Store health for single brick
	add	r0, #brickSize	// Update r0 to address of next brick

	sub	r2, #1		// Loop for each brick in the row
	bne	inner2

	sub	r1, #1		// Decrease health of bricks in next row
	bne	outer2

	bx	lr


@ Loops through the brick array to draw all the bricks on screen.
drawBricks:
	push	{r4, r5, lr}

	@ Load base address for bricks
	ldr	r4, =bricks
	ldr	r5, =endBricks

drawtop:
	mov	r0, r4
	bl	drawRect
	add	r4, #brickSize
	
	@ Check if current address is past end of array
	cmp	r4, r5
	blt	drawtop

	pop	{r4, r5, pc}

@ Sets the coordinates for all the bricks.
initBricks:
	push	{r4, r5, r6, r7}

	@ Load base address for bricks
	ldr	r0, =bricks

	@ Get # of bricks per row and # of rows
	mov	r1, #bPerRow
	mov	r2, #numRows

	xcoord	.req	r3
	ycoord	.req	r4

	@ Initialize x and y to top left part of screen
	mov	xcoord, #brickStartX
	mov	ycoord, #brickStartY
	width	.req	r6
	height	.req	r7

	mov	width, #brickWidth
	add	width, #brickSpacing

	mov	height, #brickHeight
	add	height, #brickSpacing		// Increase spacing between bricks

outer1:	@ Outer loop runs once for each row of bricks

	mov	r5, #0		@ Initialize inner counter to 0

inner1:	@ Inner loop runs once for every brick in a row

	@ Store coordinates to brick
	str	xcoord, [r0]
	str	ycoord, [r0, #4]

	@ Increment brick address and x coordinate
	add	r0, #brickSize			@ 24 bytes = size of each brick in memory		
	add	xcoord, width

	add	r5, #1
	cmp	r5, r1		@ Compare counter to # bricks per row
	blt	inner1

	add	ycoord, height		@ Increment y coordinate to new row
	mov	xcoord, #brickStartX

	subs	r2, #1		@ Loop for each row of bricks
	bne	outer1

	pop	{r4, r5, r6, r7}
	mov	pc, lr
	

@ Clears an object by drawing a black rectangle over it
@ r0 - address of the object to clear
clearObj:
	push	{r4, r5, r6}
	offset	.req	r6

	ldr	r1, =frameBufferInfo
	ldr	r2, [r0]	@ r2 = x coordinate of object
	ldr	r3, [r0, #4]	@ r3 = y coordinate
	ldr	r4, [r1, #4]	@ r4 = screen width

	@ Calculate initial offset
	mul	r3, r4		@ r1 = y * width
	add	offset, r2, r3

	ldr	r1, [r1]	@ r1 = frame buffer pointer
	ldr	r2, [r0, #8]	@ r2 = width of object
	ldr	r3, [r0, #12]	@ r3 = height of object
	mov	r5, #0		@ r5 = black color

	@ Outer loop runs <object height> times, drawing
	@ one horizontal line each time
top5:	
	@ Initialize counter for inner loop
	mov	r0, #0

top6:	@ Inner loop runs <object width> times, drawing 1
	@ pixel each time

	str	r5, [r1, offset, lsl #2]	@ Store color at physical offset
	add	offset, #1			@ Increment offset

	@ Loop while inner count is < object width
	add	r0, #1
	cmp	r0, r2
	blt	top6

	@ Move offset to next line by adding screen width - object width
	add	offset, r4
	sub	offset, r2

	@ Loop while outer count is not 0
	subs	r3, #1
	bne	top5

	pop	{r4, r5, r6}
	bx	lr


@ Draws a solid, coloured rectangle.
@ r0 - address of rectangular object to draw
drawRect:
	push	{r4, r5, r6}
	offset	.req	r6

	ldr	r1, =frameBufferInfo
	ldr	r2, [r0]	@ r2 = x coordinate of object
	ldr	r3, [r0, #4]	@ r3 = y coordinate
	ldr	r4, [r1, #4]	@ r4 = screen width
	ldr	r5, [r0, #16]	@ r5 = object colour

	@ Calculate initial offset
	mul	r3, r4		@ r1 = y * width
	add	offset, r2, r3

	ldr	r1, [r1]	@ r1 = frame buffer pointer
	ldr	r2, [r0, #8]	@ r2 = width of object
	ldr	r3, [r0, #12]	@ r3 = height of object

	@ Outer loop runs <object height> times, drawing
	@ one horizontal line each time
top1:	
	@ Initialize counter for inner loop
	mov	r0, #0

top2:	@ Inner loop runs <object width> times, drawing 1
	@ pixel each time

	str	r5, [r1, offset, lsl #2]	@ Store color at physical offset
	add	offset, #1			@ Increment offset

	@ Loop while inner count is < object width
	add	r0, #1
	cmp	r0, r2
	blt	top2

	@ Move offset to next line by adding screen width - object width
	add	offset, r4
	sub	offset, r2

	@ Loop while outer count is not 0
	subs	r3, #1
	bne	top1

	pop	{r4, r5, r6}
	bx	lr

@ Draws an image using bitmap data.
@ r0 - address of image object
.global drawImage
drawImage:
	push	{r4, r5, r6, r7}
	offset	.req	r6

	ldr	r1, =frameBufferInfo
	ldr	r2, [r0]	@ r2 = x coordinate of object
	ldr	r3, [r0, #4]	@ r3 = y coordinate
	ldr	r4, [r1, #4]	@ r4 = screen width

	@ Calculate initial offset
	mul	r3, r4		@ r1 = y * width
	add	offset, r2, r3

	ldr	r1, [r1]	@ r1 = frame buffer pointer
	ldr	r2, [r0, #8]	@ r2 = width of object
	ldr	r3, [r0, #12]	@ r3 = height of object
	add	r5, r0, #16	@ r5 = address of image data

	@ Outer loop runs <object height> times, drawing
	@ one horizontal line each time
top3:	
	@ Initialize counter for inner loop
	mov	r7, #0

top4:	@ Inner loop runs <object width> times, drawing 1
	@ pixel each time
	ldr	r0, [r5], #4			@ Load image data and update address
	str	r0, [r1, offset, lsl #2]	@ Store color at physical offset
	add	offset, #1			@ Increment offset

	@ Loop while inner count is < object width
	add	r7, #1
	cmp	r7, r2
	blt	top4

	@ Move offset to next line by adding screen width - object width
	add	offset, r4
	sub	offset, r2

	@ Loop while outer count is not 0
	subs	r3, #1
	bne	top3

	pop	{r4, r5, r6, r7}
	bx	lr

@ Data section
.section .data

.align
.global frameBufferInfo
frameBufferInfo:
	.int	0		@ frame buffer pointer
	.int	0		@ screen width
	.int	0		@ screen height

score:	.int	10
lives:	.int	3

@ window object
window:
	.int	500		@ x coordinate
	.int	100		@ y coordinate
	.int	600		@ width
	.int	800		@ height
	.int	0		@ Color (black)

ball:
	.int	ballX		@ x coordinate
	.int	ballY		@ y coordinate
	.int	ballWidth	@ width
	.int	ballWidth	@ height
.ascii "\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377X}\346\377X}\346\377X}\346\377X}\346\377X}\346\377X}\346\377"
.ascii "X}\346\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377X}\346\377j\211\343\377"
.ascii "j\211\343\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377X}\346\377\000\000\000\377\000\000\000\377\000\000\000\377"
.ascii "\000\000\000\377\000\000\000\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377"
.ascii "\247\275\350\377x\236\346\377X}\346\377\000\000\000\377\000\000\000\377\000\000\000\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "j\211\343\377x\236\346\377x\236\346\377x\236\346\377\247\275\350\377\247\275\350\377\247\275\350\377x\236\346\377X}\346\377\000\000\000\377"
.ascii "Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377"
.ascii "\247\275\350\377\247\275\350\377\247\275\350\377x\236\346\377X}\346\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "j\211\343\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377\247\275\350\377x\236\346\377x\236\346\377X}\346\377"
.ascii "Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377x\236\346\377x\236\346\377x\236\346\377"
.ascii "x\236\346\377x\236\346\377x\236\346\377x\236\346\377X}\346\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "j\211\343\377j\211\343\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377X}\346\377"
.ascii "Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377x\236\346\377x\236\346\377"
.ascii "x\236\346\377x\236\346\377x\236\346\377x\236\346\377X}\346\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "j\211\343\377j\211\343\377j\211\343\377j\211\343\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377x\236\346\377X}\346\377"
.ascii "Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "x\236\346\377x\236\346\377x\236\346\377x\236\346\377X}\346\377\000\000\000\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377X}\346\377\000\000\000\377"
.ascii "\000\000\000\377\000\000\000\377Aa\277\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377"
.ascii "j\211\343\377j\211\343\377X}\346\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377Aa\277\377j\211\343\377"
.ascii "j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377j\211\343\377X}\346\377\000\000\000\377\000\000\000\377\000\000\000\377"
.ascii "\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377Aa\277\377Aa\277\377Aa\277\377Aa\277\377Aa\277\377Aa\277\377"
.ascii "Aa\277\377\000\000\000\377\000\000\000\377\000\000\000\377\000\000\000\377"

paddle:
	.int	padX		@ x coordinate
	.int	padY		@ y coordinate
	.int	padWidth	@ width
	.int	padHeight	@ height
	.int	0x800000	@ color ("maroon")


@ Array of bricks
bricks:	.rept	10		
	.int	0		@ x coordinate
	.int	0		@ y coordinate
	.int	brickWidth	@ width
	.int	brickHeight	@ height
	.int	0xFF5733	@ Color (red)
	.int	3		@ Health
	.endr

	.rept	10	
	.int	0		@ x coordinate
	.int	0		@ y coordinate
	.int	brickWidth	@ width
	.int	brickHeight	@ height
	.int	0x3EF2F7	@ Color (blue)
	.int	2		@ Health
	.endr

	.rept	10		
	.int	0		@ x coordinate
	.int	0		@ y coordinate
	.int	brickWidth	@ width
	.int	brickHeight	@ height
	.int	0x87F36D	@ Color (green)
	.int	1		@ Health
	.endr
endBricks:













	
