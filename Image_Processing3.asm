.data
	imageaddress: .word 0 #base address of image

.data 0x10110000

image: .space 1048576 	# 1.048.576 = 0x 10 0000

.data 0x10210000
	kernel_Prewitt_X: .byte +1,0,-1,+1,0,-1,+1,0,-1
	kernel_Prewitt_Y: .byte -1,-1,-1,0,0,0,+1,+1,+1
	kernel_Sobel_X: .byte +1,0,-1,+2,0,-2,+1,0,-1
	kernel_Sobel_Y: .byte -1,-2,-1,0,0,0,+1,+2,+1
	x: .byte 0
	msg_I: .asciiz " \n Enter the name of the image you want to edit (e.g., name.bmp)\n >"
	Error_msg: .asciiz " File not found.\n Press ENTER to enter the image name again"
	Format_Error_msg: .asciiz "This file is not in the correct format (Invalid file signature)\n Try another name\n"
	menu_msg: .asciiz " \nSelect an option:\n 1. Blurring\n 2. Edge Extraction\n 3. Threshold\n 4. Change image\n 5. Apply current effect\n 6. RESET\n 0. Exit\nOption: "
	invalidop_msg: .asciiz " \n \n Invalid option. Press ENTER to return to the menu!\n"
	blur_degree: .asciiz "Choose the degree of blurring (from 1 to 5)\n> "
	Edge_option: .asciiz "Choose the edge extraction mask:\n 1. Prewitt\n 2. Sobel\n 0. Go back to the previous menu\n> "
	Threshold_msg: .asciiz "\nChoose a threshold (from 0 to 255)\n> "
	Processing_msg: .asciiz "Processing...\n"
	
	filename: .space  64   # Allocate 64 bytes for the filename
	
	
	buff: .word 0
	header: .space 54
	
	bytesPerline: .word 0 #number of bytes per line (width in pixels *4)
	height:.word 0	#image height
	original: .word 0
	
.text
Start:
	li $v0, 4
	la $a0,msg_I
	syscall  #print msg and prepare to read import file name

	li $v0,8
	la $a0,filename
	li $a1,20
	syscall	  # read the  file name

	#to remove \n from the end of the read string 
	addiu $t7,$0,-1     
	newlinechrloop: 
		addiu $t7,$t7,1
		lbu $s0,filename($t7)
		bne $s0,'\n',newlinechrloop 
	sb $0,filename($t7) #  (Store Byte)  Replace newline with null terminator

    # Open the file for reading
	li $v0,13  #//no. 13  is to open
	la $a0,filename    #//Loads the address of the filename buffer into register $a0 
	li $a1,0      #//indicating read-only mode 
	li $a2,0    #//Sets register $a2 to 0. This parameter is typically used to specify file permissions, but it's not needed for read mode, so it's set to 0.
	syscall 
	move $s6,$v0  

	#error if $v 0 is less than 0
	slti $t0, $v0, 0
	beq $t0, 0, mainpart  # normally follows to main if $v0 > 0
	li $v0, 4
	la $a0,Error_msg
	syscall   # print error message
	li $v0,8
	la $a0,x
	li $a1,1
	syscall
	j Start

mainpart:
	li $v0, 4
	la $a0, Processing_msg
	syscall   # print processing  ..  message
	
	#header
	move $s0,$zero
	li $v0,14		# file read call parameter
	move $a0, $s6		# move descriptor to $a0
	la $a1, header	# read the signature to see if it really is a .bmp file
	li $a2, 54		# max character size
	syscall			# returns the number of characters read

	#To verify signature
	lhu $t0,header
	beq $t0,0x4D42,continue_reading	#continue reading if format is correct
	li $v0, 4
	la $a0, Format_Error_msg
	syscall   #print error message
	j Start
	
	continue_reading:
	 # loading bytes from specific offsets in the header buffer 
	 #to extract the width and height information.
		# Width
		li $t0, 0             # Initialize $t0 to 0
		li $t1, 0             # Initialize $t1 to 0
      	lbu $t0, header+18    # Load the byte representing the width from the header
    	lbu $t1, header+19    # Load the next byte representing the width from the header
    	sll $t1, $t1, 8       # Shift the second byte to the left by 8 bits
   		or $t0, $t0, $t1      # Combine the two bytes to form the width
   		mulou $t0, $t0, 4     # Multiply the width by 4 (assuming each pixel takes 4 bytes)
   		sw $t0, bytesPerline  # Store the result in the bytesPerline variable

		#height
		li $t0,0
		li $t1,0
		lbu $t0,header+22
		lbu $t1,header+23
		sll $t1,$t1,8
		or $t0,$t0,$t1	
		sw $t0,height


	reading:
		li $v0,14		# file read call parameter
		move $a0, $s6		# file read call parameter
		la $a1, buff	# address for storing read data
		li $a2, 3		 # max character size
		syscall			# returns the number of characters read
		beqz $v0,endreading
		
		lw $t0,buff
		sw $t0,original($s0)
		addi $s0,$s0,4
		j reading
	
	endreading:
		subi $s0,$s0,4		#s0 stores the number of bytes
		
		li $v0,16		# close file
		move $a0, $s6
		syscall
		
	jal flip_vertical
	
	#show image
		la $s1, original		# s1 = original image
		la $s3, image			#s3 = bitmapdisp
		move $s4, $zero			# i = 0

		loop:
			bge $s4, $s0, menu
			lw $s2, ($s1)
			sw $s2, ($s3)
			addi $s1, $s1, 4
			addi $s3, $s3, 4
			addi $s4, $s4, 4
			j loop
	

##########################################################

menu: 
	li $v0, 4
	la $a0, menu_msg
	syscall    #print the menu
	
	li $v0, 5       
 	syscall	   # reading option 	

 	sltiu $t1, $v0, 8
	
	bnez  $t1, continue
	li $v0, 4
	la $a0, invalidop_msg
	syscall   #print the message
	li $v0,8
	la $a0,x
	li $a1,1
	syscall
	j menu
		continue:
			beq $v0, 1, Blur
			beq $v0, 2, Edge
			beq $v0, 3, Binarization
			beq $v0, 4, Start
			beq $v0, 7, Reset
			
			exit:
				li $v0, 10
				syscall


##########################################################################################

Blur:	
	la $t0,original
	la $t8,image
	li $v0, 4
	la $a0, blur_degree
	syscall   # print asking for degree of blurring

	li $v0,5	
	syscall
	move $s2,$v0	# degree of interpolation
	
	li $v0,4
	la $a0, Processing_msg
	syscall  # print the message

	lw $t3,bytesPerline		 #number of bytes per line

	mulo $t3,$s2,$t3	
	mulo $t2,$s2,4		
	add $s7,$t3,$t2		#constant to be subtracted from the memory position of the central pixel of the matrix, to reach the beginning of the matrix that will be interpolated
	mulo $s5,$s2,2
	addi $s5,$s5,1 		#number of columns
	mulo $s6,$s5,4		#number of bytes within an interpolation line

	subi $t0,$t0,4
	subi $t8,$t8,4
	li $s1,0
	loop2:	
		bge $s1,$s0,fim_loop2
		addiu $t0,$t0,4
		addiu $t8,$t8,4
		addi $s1,$s1,4
		li $s4,0		# stores the final pixel value
	
		# s3 start of interpolation
		sub $s3,$t0,$s7
		move $t7,$s3	# t7 to the position of the line read
		li $t1,0		#counts interpolated lines
		li $t2,0		# t2 counts the interpolation pixels
		li $t4,0		 # sum of blue intensity
		li $t5,0		# sum of green intensity
		li $t6,0		# sum of red intensity
		li $t9,0		#counts interpolated columns
		loop3:
			bge $t1,$s5,end_array
			lbu $t3,($s3)
			add $t4,$t4,$t3
			addi $s3,$s3,1
		
			lbu $t3,($s3)
			add $t5,$t5,$t3
			addi $s3,$s3,1		
			
			lbu $t3,($s3)
			add $t6,$t6,$t3
			addi $s3,$s3,2	
					
			addi $t2,$t2,1
			addi $t9,$t9,4
			bge $t9,$s6,end_of_line
			j loop3
	end_of_line:
		addi $t1,$t1,1
		lw $s3,bytesPerline
		add $t7,$t7,$s3	#goes to the next line of the interpolation matrix
		move $s3,$t7
		li $t9,0
		j loop3
	end_array:
		divu $t4,$t4,$t2
		move $s4,$t4
		divu $t5,$t5,$t2
		sll $t5,$t5,8
		divu $t6,$t6,$t2
		sll $t6,$t6,16
		or $s4,$s4,$t5
		or $s4,$s4,$t6
		sw $s4,($t8)
		j loop2
fim_loop2:
j print

#####################################################################
Edge:
	addi $sp,$sp,-40 #creates spaces for variables on the stack
	sw $a1,36($sp)
	sw $a0,32($sp)
	sw $ra,28($sp)
	sw $s6,24($sp)
	sw $s5,20($sp)
	sw $s4,16($sp)	
	sw $s3,12($sp)
	sw $s2,8($sp)
	sw $s1,4($sp)
	sw $s0,0($sp)	# stack variables


	#la $s0,original		#source image
	#la $s1,image		#image destination
	lw $s2,bytesPerline
	srl $s2,$s2,2		 #number of pixels (words) per line
	lw $s3,height		#number of lines

	move $t0, $s6		 # $s6 = size of the img in bytes

	repeatEdge:	
	li $v0, 4
	la $a0, Edge_option
	syscall   # prints asking method: 1.Prewitt 2. Sobel 3.Line Detector
	
	li $v0, 5       
 	syscall	  # reading option

	beq $v0,0,prevmenu
	beq $v0,1,prewitt
	beq $v0,2,sobel


	j repeatEdge

	# load memory location of desired kernel
	prewitt:
		la $s4,kernel_Prewitt_X
		la $s5,kernel_Prewitt_Y
		li $s6, 3	 # number to be averaged
		j EdgeLoop
	sobel:	
		la $s4,kernel_Sobel_X
		la $s5,kernel_Sobel_Y
		li $s6, 4	 # number to be averaged
		j EdgeLoop

	EdgeLoop:
	#calculates initial position of the kernel (origin at the center of the kernel)
	li $t7,1	#kernel x position
	li $t8,1	#kernel y position

	# main loop (moves grid until it reaches the end)
	loopExBorda:
		#calculate position in memory using cursors
		mul $t9,$s2,$t8 # numPixLin*y
		add $t9,$t9,$t7	# +x
		sll $s7,$t9,2	# position in word
		la $a0,original($s7)	#absolute address of the pixel
		# calculate pixel value using X grid

		move $a1,$s4		#argument a1 = kernel address
		jal calculatePixel
			move $s0,$v0
			bgtz $v0, valorXzero	# value of the x component is zero if v0 is negative
			sub $s0,$zero,$v0		# $s0 = value of the X component
			valorXzero:
		# calcula valor do pixel usando a grade Y
		move $a1,$s5		#argument a1 = kernel address
		jal calculatePixel	
			move $s1,$v0
			bgtz $v0, valorYzero	# valor da componente x eh zero se v0 eh negativo
			sub $s1,$zero,$v0		# $s0 = valor da componente X
			valorYzero:			
								
		# calculates what the byte looks like and records value as pixel
		sll $s0,$s0,8	#positions as green
		sll $s1,$s1,16	#positions as red
		or $t9,$s0,$s1
		sw $t9,image($s7)	#saves pixel in image position

		# increment position and check if finished and return to loopExBorda
		addi $t7,$t7,1			 # increment cursor

		#srl $t9,$s2,2			# numBytes/4 (numPixels)
		add $t9,$s2,-1			# $t9 = numPixels - 1
		blt $t7,$t9,loopExBorda		 #jump if there are still elements on the right

		li $t7,0		#zero X
		addi $t8,$t8,1		 #increment Y
		add $t9,$s3,-1
		blt $t8,$t9,loopExBorda		#jump if there are still elements below

	prevmenu:
	lw $s0,0($sp)	# pops variables
	lw $s1,4($sp)
	lw $s2,8($sp)	
	lw $s3,12($sp)
	lw $s4,16($sp)
	lw $s5,20($sp)
	lw $s6,24($sp)	
	lw $ra,28($sp)
	lw $a0,32($sp)
	lw $a1,36($sp)
	addi $sp,$sp,40	# frees up space on the stack
	j print


	calculatePixel:	# $a0 = &pixel, $a1 = &kernel
		#la $s0,original	#source image
		#la $s1,image		#image destination	
		li $t0, -1 #column cursor
		li $t1, -1 #line cursor
		li $t2, 0 #accumulator (does the average at the end)
		loopCalcPix:

				#calculates pixel position in memory
				# imgPos + 4*(cursCol + pixelsPerLine*cursLin)
				mulu $t5,$s2,$t1 # pixelsPerLine*cursLin
				add $t5,$t5,$t0 # + cursColEmWords
				sll $t5,$t5,2 # *4
				add $t5,$t5,$a0	# address in image
			#load green value in position to register
				lhu $t5,0($t5)
				srl $t6,$t5,8
			#multiply with the weight (to be calculated too) and add to the accumulator
				# &peso = &kernel+(cursCol+3*cursLin)
				mul $t5,$t1,3 	# 3*cursLin
				add $t5,$t5,$t0	# +cursCol
				add $t5,$t5,4	# puts it at the origin of the mask
				add $t5,$t5,$a1 # +&kernel

				lb $t5,0($t5)	# $t5 <- weight
				mul $t5,$t5,$t6 # peso * green
				add $t2,$t2,$t5 # add result to accumulator
			#increment cursors and return to secondary loop, exit if finished
			addi $t0,$t0,1	#increment 'x'
			bne $t0,2,loopCalcPix
			li $t0,-1
			addi $t1,$t1,1	#increment 'y'
			bne $t1,2,loopCalcPix
		#normalizes the value
		div $t2,$s6
		#save result in $v0
		mflo $v0
		jr $ra


#####################################################################
#black and white
Binarization:
	
	li $v0, 4
	la $a0, Threshold_msg
	syscall  # print the message

	li $v0,5	
	syscall
	move $s2,$v0	 # degree of interpolation

	li $v0, 4
	la $a0, Processing_msg
	syscall  # print the message
	
	la $s1, original		# s1 = image
	la $s3, image			# s3 = bitmapdisp
	move $s4, $zero			# i = 0
	
	addi $s1,$s1,2			#checks the green byt
	loop4:
		
		bge $s4, $s0, print
		lbu $t0,($s1)		
		bgt $t0,$s2,white
		j black
			white:
				li $t1,0x00FFFFFF
				j continueB
			black:
				li $t1,0
				
		continueB:
		sw $t1, ($s3)
		addi $s1, $s1, 4
		addi $s3, $s3, 4
		addi $s4, $s4, 4
		j loop4
###########################################################

Reset:



	
##########################################################
flip_vertical:
	
		move $t5, $0		# j = 0
		lw $s1,bytesPerline
		lw $s2,height
		
		sub $s3,$s2,1
		mulo $s3,$s3,$s1	#s3 is the constant to reach the first pixel of the last line of the image
		
		div $s2,$s2,2	# middle of image
        div $s4,$s1,4 #s4 is the width of the image

		
		flip_vert:
		bge $t5, $s2, end_flip_vert
		la $t0, original		# x0, y0
		add $t1, $t0, $s3	# x0, y min;
		mulo $t6, $t5, $s1	# adjust line
		add $t0, $t0, $t6	 # t0 = line (j)

		sub $t1, $t1, $t6	# t1 = -line (j)+512


		move $t4, $0		# i = 0
		swap:
			bge $t4, $s4,end_swap
			lw $t2, ($t0)		# swap
			lw $t3, ($t1)
			sw $t3, ($t0)
			sw $t2, ($t1)
			addi $t0, $t0, 4
			addi $t1, $t1, 4
		
			addiu $t4, $t4, 1	# i ++
			j swap
		end_swap:

			addi $t5, $t5, 1	# j++
			j flip_vert
		end_flip_vert:
		jr $ra

#################################################################
print:
	la $s1, image			# s1 = image
	la $s3, imageaddress	# s3 = bitmapdisp
	move $s4, $zero			# i = 0

	loopP:
		bge $s4, $s0, menu
		lw $s2, ($s1)
		sw $s2, ($s3)
		addi $s1, $s1, 4
		addi $s3, $s3, 4
		addi $s4, $s4, 4
		j loopP