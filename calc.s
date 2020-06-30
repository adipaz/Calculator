section	.rodata							; we define (global) read-only variables in .rodata section
	format_msbNumber: db "%X",0		; format msb number
    format_number: db "%02hhX",0		; format number
    format_string: db "%s",0		; format string


section .bss			; we define (global) uninitialized variables in .bss section


section .data
    stackSize: dd 20
    stackBottom: dd 0
    stackTop: dd 0
    stackPointer: dd 0
    calcString: db 'calc: ' ,0
    pushString: db 'push: ' ,0
    popString: db 'pop: ' ,0
    counter: db 0    
    num: db 0 
    carry: db 0 
    tempCarry: db 0 
    first: dd 0
    temp: dd 0
    prev: dd 0
    op1: dd 0
    op2: dd 0
    op1num: db 0
    op2num: db 0
    prevOp1: dd 0
    prevOp2: dd 0
    newLine: db 10,0
    errStackOverflow: db 'Error: Operand Stack Overflow',10 ,0
    errInsufficent: db 'Error: Insufficient Number of Arguments on Stack',10 ,0
    operationsCounter: dd 0
    bckN: dd 10,0
    debug: dd 0     ;debug=0 - regular mode. debug=1 - debug mode

    
section .text
  align 16
  global main
  extern printf
  extern fprintf 
  extern malloc 
  extern free 
  extern getchar 
  extern stderr 
  global printList
  global printListForDebug
  global count

%macro convertCharToNumber 0
    sub al,'0'
    cmp al,9
    jle %%finishConvert
    sub al,7
%%finishConvert:
%endmacro

%macro initStackPointer 0
    mov eax,[stackPointer]
    mov dword [eax],0
%endmacro

%macro multBy16 1 
    shl %1,4
    mov bl,%1
%endmacro

%macro checkStackOverFlow 1
    mov ebx,dword[stackPointer]
    cmp ebx,dword[stackTop]
    jnz %1
    pushad 
    push errStackOverflow    
    push format_string
    push dword[stderr]
    call fprintf
    add esp,12
    popad
%%ezer:
    cmp byte[temp],10
    jz %%ezer2
    call getchar
    mov byte[temp],al
    jmp %%ezer
%%ezer2:
    jmp displayCalc
%endmacro



%macro checkForOneArgInStack 1
    mov ebx,dword[stackPointer]
    cmp dword[stackBottom],ebx
    jnz %1 
    pushad 
    push errInsufficent 
    push format_string   
    push dword[stderr]
    call fprintf
    add esp,12
    popad
    jmp displayCalc
%endmacro

%macro checkForTwoArgsInStack 1
    mov ebx,dword[stackPointer]
    sub ebx,8
    cmp ebx,dword[stackBottom]
    jge %1 
    pushad 
    push errInsufficent 
    push format_string   
    push dword[stderr]
    call fprintf
    add esp,12
    popad
    jmp displayCalc
%endmacro

%macro stpInTemp 0
    mov ebx,[stackPointer]
    mov ebx,dword[ebx]
    mov dword[temp],ebx
%endmacro

%macro InitPrev 0
    mov ebx,dword[stackPointer]
    sub ebx,4
    mov ebx,dword[ebx]
    mov dword[prev],ebx
%endmacro

%macro getOp 2
    mov ebx,dword[stackPointer]
    sub ebx,4
    mov dword[stackPointer],ebx
    mov ebx,dword[ebx]
    mov dword[%1],ebx
    mov dword[%2],ebx
%endmacro

%macro updateOp 2 
    mov byte[%2],0
    cmp dword[%1],0
    je %%endUpdate
    mov ebx,dword[%1]
    mov bl,byte[ebx]
    mov byte[%2],bl
    mov ebx,dword[%1]
    mov ebx,dword[ebx+1]
    mov dword[%1],ebx
%%endUpdate:
%endmacro

%macro printNumber 1
    pushad
    push dword [%1]
    push format_msbNumber
    call printf
    add esp,8
    popad

    pushad
    push newLine
    call printf
    add esp,4
    popad
%endmacro

%macro checkDebugAndPrintNum 1
    cmp dword [debug], 1
    jnz %%noDebug

    pushad    
    push %1
    push format_string
    push dword[stderr]
    call fprintf
    add esp,12
    popad

    pushad
    call printListForDebug
    popad

    pushad
    push newLine
    push dword[stderr]
    call fprintf
    add esp,8
    popad
%%noDebug:
%endmacro

main:
    push ebp              		
    mov ebp, esp 

    jmp getStackSize  
    retFromSize:        

    jmp checkDebug
    retFromDebugCheck:

    ;malloc to stackBottom with stackSize
    push dword [stackSize]
    call malloc
    mov [stackBottom], eax

    ;setting stack pointers
    mov eax, [stackBottom]  ;set stack bottom
    add eax, [stackSize]         
    mov dword[stackTop], eax  ;set stack top as stack bottom + stack size
    mov ebx, dword [stackBottom]
    mov [stackPointer], ebx   ;set stack pointer as stack bottom

displayCalc:
    ;display calcString and wait for input 
    pushad    
    push calcString
    push format_string
    call printf
    add esp,8
    popad

    mov ebx,dword[stackPointer]
    cmp ebx,dword[stackTop]
    jz getInput

    initStackPointer  ; set stack pointer to point on address 0

getInput:

    ;get first char
    call getchar

    ;check for command
    cmp al,'q'
    jz finish
    cmp al,'p'
    jz p_command 
    cmp al,'n'
    jz n_command 
    cmp al,'d'
    jz d_command 
    cmp al,'&'
    jz and_command 
    cmp al,'|'
    jz or_command 
    cmp al,'+'
    jz add_command 
    cmp al,10
    jz continue 

    ;convert to number
    convertCharToNumber
    mov byte [num],al

    ;get second char
    call getchar

    ;check for end of line
    mov byte [temp],al
    cmp al,10
    jz addLink

    ;multiply first num by 16
    mov bl,byte [num]
    multBy16 byte [num]

    ;convert to number
    convertCharToNumber
    mov byte [num],al

    ;add first num to second num
    add byte[num],bl


addLink:

    checkStackOverFlow continueAddLink

continueAddLink: 

    push 5
    call malloc ;allocate 5 bytes for the new link, pointer to the new link is now in eax


    mov ebx ,0
    add bl, byte [num]  ;bl = num to be restored in the first byte of the link 
    mov byte [eax],bl ;restore the num in the first byte of the new link 
    mov ebx,[stackPointer] 
    mov ebx,[ebx]  ;ebx = the address of the previous link
    mov dword [eax+1],ebx  ;put the address of the previous link in the last 4 bytes of the new link
    mov ebx,[stackPointer]
    mov dword [ebx],eax ;put the pointer to the new link in the stack pointer

    cmp byte[temp],10
    jnz getInput

    mov dword[prev],eax ;prev = the address of the link with the single char
    mov ebx,dword[eax+1]
    mov dword[temp],ebx ;temp = the address of the following link


shiftOdd:
    cmp dword[temp],0
    jz continue
    mov ecx,dword[temp]
    mov bl,byte[ecx]
    shr byte[ecx],4 
    shl bl,4
    mov ecx,dword[prev]
    add byte[ecx],bl 

    mov ebx,dword[temp]
    mov dword[prev],ebx
    mov ebx,dword[ebx+1]
    mov dword[temp],ebx
    jmp shiftOdd


    

    
continue:

    mov ebx,dword[stackPointer]
    mov ecx,dword[ebx]
    mov dword[temp],ecx
    mov dword[first],ecx
    mov dword[prev],ecx
    call handleLeadingZeroes

    mov ebx,dword[stackPointer]
    mov ecx,dword[ebx]
    mov dword[temp],ecx
    checkDebugAndPrintNum pushString

    mov ebx,dword[stackPointer]
    add ebx,4 
    mov dword[stackPointer],ebx  ;update the stack pointer to next address
    jmp displayCalc




;***********************************P_COMMAND************************************************


p_command:
    ;increment operationsCounter
    inc dword [operationsCounter]
    call getchar ;get the \n after the command
    checkForOneArgInStack continueP_command

continueP_command:
    mov ebx,[stackPointer]
    sub ebx,4 
    mov ebx,dword[ebx]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString

    mov ebx,[stackPointer]
    sub ebx,4
    mov dword[stackPointer],ebx ;update the stack pointer to the last argument in the stack
    mov ebx,dword[ebx]
    mov dword[temp],ebx ;temp = the head of the linked list that represents the last argument in the stack
    call printList

    pushad
    push newLine
    call printf
    add esp,4
    popad

    

    jmp displayCalc




;***********************************N_COMMAND************************************************

n_command:
    ;increment operationsCounter
    inc dword [operationsCounter]
    call getchar ;get the \n after the command
    checkForOneArgInStack countinueN_command

countinueN_command:
    mov ebx,[stackPointer]
    sub ebx,4 
    mov ebx,dword[ebx]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString

    mov ebx,[stackPointer]
    sub ebx,4 
    mov dword[stackPointer],ebx ;update the stack pointer to the last argument in the stack
    mov ebx,dword[ebx]
    mov dword[temp],ebx ;temp = the head of the linked list that represents the last argument in the stack
    mov byte[counter],0
    call count 
    stpInTemp
    call freeList

    push 5
    call malloc

    mov ecx,0
    mov cl,byte[counter]
    mov byte[eax],cl
    mov dword[eax+1],0
    mov ebx,[stackPointer]
    mov dword [ebx],eax ;put the pointer to the new link in the stack pointer




    jmp continue


;***********************************D_COMMAND************************************************

d_command:
    ;increment operationsCounter
    inc dword [operationsCounter]
    call getchar ;get the \n after the command
    mov byte[temp],al
    checkStackOverFlow continueCheckDCommand
continueCheckDCommand:
    checkForOneArgInStack countinueD_command

countinueD_command:
    InitPrev ; prev = the list to duplicate

    push 5
    call malloc
    mov dword[temp],eax
    mov ecx,0
    mov ebx,dword[prev]
    mov cl,byte[ebx]
    mov byte[eax],cl
    mov ebx,dword[stackPointer]
    mov dword[ebx],eax ;dup the first link
    mov ebx,dword[prev]
    cmp dword[ebx+1],0
    jz finishDup
dupList:
    mov ebx,dword[prev]
    mov ebx,dword[ebx+1]
    mov dword[prev],ebx ;prev = the next link to dup
    push 5
    call malloc 
    mov ebx,dword[temp]
    mov dword[ebx+1],eax ; add pointer to the new dup link 
    mov ebx,dword[prev]
    mov ecx,0
    mov cl,byte[ebx]
    mov byte[eax],cl ;dup the curr num to the new link 
    mov ebx,dword[prev]
    cmp dword[ebx+1],0
    mov dword[temp],eax
    jz finishDup
    jmp dupList

finishDup:
    mov ebx,dword[temp]
    mov dword[ebx+1],0

    

    jmp continue





;***********************************AND_COMMAND************************************************

and_command: 
    ;increment operationsCounter
    inc dword [operationsCounter]
    call getchar ;get the \n after the command
    checkForTwoArgsInStack continueAnd_command

continueAnd_command:
    getOp op1,prevOp1 ;op1 = the last arg in the stack
    getOp op2,prevOp2 ;op2 = one arg before the last arg in the stack

    mov ebx,dword[op1]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString
    mov ebx,dword[op2]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString


    push 5
    call malloc 
    mov dword[temp],eax
    mov edx,dword[op1]
    mov ecx,0
    mov cl,byte[edx]
    mov edx,dword[op2]
    mov ebx,0
    mov bl,byte[edx]
    and bl,cl
    mov byte[eax],bl
    mov ebx,dword[stackPointer]
    mov dword[ebx],eax

startAnd:
    mov ebx,dword[op1]
    mov ecx,dword[ebx+1] ;ecx = next link of op1
    mov ebx,dword[op2]
    mov edx,dword[ebx+1] ;edx = next link of op2
    mov dword[op1],ecx
    mov dword[op2],edx
    cmp ecx,0
    jz finishAnd
    cmp edx,0
    jz finishAnd
    


    push 5
    call malloc
    mov ebx,dword[temp]
    mov dword[ebx+1],eax ; add pointer to the new and link
    mov dword[temp],eax 
    mov edx,dword[op1]
    mov ecx,0
    mov cl,byte[edx]
    mov edx,dword[op2]
    mov ebx,0
    mov bl,byte[edx]
    and bl,cl
    mov byte[eax],bl
    jmp startAnd

finishAnd:
    mov ebx,dword[temp]
    mov dword[ebx+1],0
    mov ebx,dword[prevOp1]
    mov dword[temp],ebx
    call freeList
    mov ebx,dword[prevOp2]
    mov dword[temp],ebx
    call freeList

    

    jmp continue




;***********************************OR_COMMAND************************************************

or_command: 
    ;increment operationsCounter
    inc dword [operationsCounter]
    call getchar ;get the \n after the command
    checkForTwoArgsInStack continueOr_command

continueOr_command:
    getOp op1,prevOp1 ;op1 = the last arg in the stack
    getOp op2,prevOp2 ;op2 = one arg before the last arg in the stack


    mov ebx,dword[op1]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString
    mov ebx,dword[op2]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString

    push 5
    call malloc 
    mov dword[temp],eax
    mov edx,dword[op1]
    mov ecx,0
    mov cl,byte[edx]
    mov edx,dword[op2]
    mov ebx,0
    mov bl,byte[edx]
    or bl,cl
    mov byte[eax],bl
    mov ebx,dword[stackPointer]
    mov dword[ebx],eax

startOr:
    mov ebx,dword[op1]
    mov ecx,dword[ebx+1] ;ecx = next link of op1
    mov ebx,dword[op2]
    mov edx,dword[ebx+1] ;edx = next link of op2
    mov dword[op1],ecx
    mov dword[op2],edx
    cmp ecx,0
    jz endOfOp1_Or
    cmp edx,0
    jz endOfOp2_Or
    


    push 5
    call malloc
    mov ebx,dword[temp]
    mov dword[ebx+1],eax ; add pointer to the new and link
    mov dword[temp],eax 
    mov edx,dword[op1]
    mov ecx,0
    mov cl,byte[edx]
    mov edx,dword[op2]
    mov ebx,0
    mov bl,byte[edx]
    or bl,cl
    mov byte[eax],bl
    jmp startOr



endOfOp1_Or:
    mov ebx,dword[op2] ;ebx = the address of the current link
    cmp ebx,0
    jz finishOr
    push 5
    call malloc
    mov ecx,dword[temp]
    mov dword[ecx+1],eax
    mov dword[temp],eax
    mov ecx,0
    mov cl,byte[ebx]
    mov byte[eax],cl ;copy the num of the current link in op2 to the new link
    mov ebx,dword[ebx+1]
    mov dword[op2],ebx
    jmp endOfOp1_Or

endOfOp2_Or:
    mov ebx,dword[op1] ;ebx = the address of the current link
    cmp ebx,0
    jz finishOr
    push 5
    call malloc
    mov ecx,dword[temp]
    mov dword[ecx+1],eax
    mov dword[temp],eax
    mov ecx,0
    mov cl,byte[ebx]
    mov byte[eax],cl ;copy the num of the current link in op2 to the new link
    mov ebx,dword[ebx+1]
    mov dword[op1],ebx
    jmp endOfOp2_Or

finishOr:
    mov ebx,dword[temp]
    mov dword[ebx+1],0
    mov ebx,dword[prevOp1]
    mov dword[temp],ebx
    call freeList
    mov ebx,dword[prevOp2]
    mov dword[temp],ebx
    call freeList

   

    jmp continue





;***********************************ADD_COMMAND************************************************

add_command:
    ;increment operationsCounter
    inc dword [operationsCounter]
    call getchar ;get the \n after the command
    checkForTwoArgsInStack continueAdd_command

continueAdd_command:
    getOp op1,prevOp1 ;op1 = the last arg in the stack
    getOp op2,prevOp2 ;op2 = one arg before the last arg in the stack

    mov ebx,dword[op1]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString
    mov ebx,dword[op2]
    mov dword[temp],ebx
    checkDebugAndPrintNum popString

    mov byte[carry],0
    mov byte[tempCarry],0
    mov dword[first],0
    mov dword[temp],0

addLoop:
    mov byte[tempCarry],0
    mov eax,0
    add eax,dword[op1]
    add eax,dword[op2]
    cmp eax,0
    jz lastCarry
    updateOp op1,op1num ;now op1num is the num in op1 or 0 if op1 points to zero
    updateOp op2,op2num ;now op2num is the num in op2 or 0 if op2 points to zero
    mov byte[num],0
    mov bl,byte[op1num]
    add bl,byte[carry]
    jnc afterCarry1
    mov byte[tempCarry],1
afterCarry1:
    add bl,byte[op2num]
    jnc afterCarry2
    mov byte[tempCarry],1
afterCarry2:
    mov cl,byte[tempCarry]
    mov byte[carry],cl
    mov byte[num],bl  ;now num is the num to put in the new link

    push 5
    call malloc
    cmp  dword[first],0
    jnz firstIsUpdated
    mov dword[first],eax
firstIsUpdated: 
    mov bl,byte[num]
    mov byte[eax],bl
    cmp dword[temp],0
    jz updateTemp
    mov ebx,dword[temp]
    mov dword[ebx+1],eax 
updateTemp:
    mov dword[temp],eax
    jmp addLoop



lastCarry:
    cmp byte[carry],0
    jz finishAdd
    push 5
    call malloc
    mov byte[eax],1
    mov ebx,dword[temp]
    mov dword[ebx+1],eax 
    mov dword[temp],eax


finishAdd:
    mov ecx,dword[stackPointer]
    mov edx,dword[first]
    mov dword[ecx],edx
    mov ebx,dword[temp]
    mov dword[ebx+1],0
    mov ebx,dword[prevOp1]
    mov dword[temp],ebx
    call freeList
    mov ebx,dword[prevOp2]
    mov dword[temp],ebx
    call freeList

    

    jmp continue




;********************************************FINISH_PROGRAM************************************************************

finish: 

    ;print operationsCounter
    printNumber operationsCounter
 
    mov ebx,dword[stackBottom]
    mov dword[prev],ebx
    mov ecx,dword[stackPointer]
    cmp dword[prev],ecx
    jz freeStack

freeOperands:
    mov ebx,dword[prev]
    mov ebx,dword[ebx]
    mov dword[temp],ebx
    pushad
    call freeList
    popad
    add dword[prev],4
    mov ecx,dword[stackPointer]
    cmp dword[prev],ecx
    jnz freeOperands

    mov ebx,dword[stackBottom]
    mov dword[temp],ebx
    mov ecx,dword[stackTop]
    cmp dword[temp],ecx
    jz finishProgram
 freeStack:
    push dword[stackBottom]
    call free 
    add esp,4
	
finishProgram:        			
    mov esp, ebp	
    pop ebp
    ret






printList: 
    push ebp              		
    mov ebp, esp 
    mov ebx,[temp]
    mov eax,ebx
    mov ecx,0
    mov cl,byte[ebx] ; what to print
    cmp dword[ebx+1],0
    jz printMsbNum
    mov ebx,dword[ebx+1]
    mov dword[temp],ebx
    pushad
    call printList
    popad
printNum :
    pushad
    push ecx 
    push format_number
    call printf
    add esp,8
    popad
    jmp freeNum
printMsbNum :
    pushad
    push ecx 
    push format_msbNumber
    call printf
    add esp,8
    popad
freeNum:
    push eax
    call free 
    add esp,4
    mov esp, ebp	
    pop ebp
    ret



printListForDebug: 
    push ebp              		
    mov ebp, esp 
    mov ebx,[temp]
    mov eax,ebx
    mov ecx,0
    mov cl,byte[ebx] ; what to print
    cmp dword[ebx+1],0
    jz printMsbNum1
    mov ebx,dword[ebx+1]
    mov dword[temp],ebx
    pushad
    call printListForDebug
    popad
printNum1 :
    pushad
    push ecx 
    push format_number
    push dword[stderr]
    call fprintf
    add esp,12
    popad
    jmp finishPrint
printMsbNum1 :
    pushad
    push ecx 
    push format_msbNumber
    push dword[stderr]
    call fprintf
    add esp,12
    popad
finishPrint:
    mov esp, ebp	
    pop ebp
    ret




count:
    push ebp              		
    mov ebp, esp 
startCount:
    mov ebx,dword[temp]
    inc byte[counter]
    inc byte[counter]
    mov ecx,dword[ebx+1]
    cmp ecx,0
    jz finishCount
    mov dword[temp],ecx
    jmp startCount
finishCount:
    mov bl,byte[ebx]
    shr bl,4
    cmp bl,0
    jg finalCount
    dec byte[counter]
finalCount:
    mov esp, ebp	
    pop ebp
    ret



freeList:
    push ebp              		
    mov ebp, esp 
startFree:
    mov ebx,dword[temp]
    mov ecx,dword[ebx+1]
    pushad
    push ebx
    call free 
    add esp,4
    popad
    cmp ecx,0
    jz finishFree
    mov dword[temp],ecx
    jmp startFree
finishFree:
    mov esp, ebp	
    pop ebp
    ret






handleLeadingZeroes:
    push ebp              		
    mov ebp, esp 

findFirstZero:
    mov ebx,dword[temp]
    cmp ebx,0
    jz startDeleteZeroes
    cmp byte[ebx],0
    jnz case1
    mov ecx,dword[prev]
    cmp byte[ecx],0
    jz advanceTemp
case1: 
    mov dword[prev],ebx
advanceTemp:
    mov ebx,dword[ebx+1]
    mov dword[temp],ebx
    jmp findFirstZero


startDeleteZeroes:
    mov ebx,dword[prev]
    cmp byte[ebx],0
    jnz finishZeroes
    cmp ebx,dword[first]
    jz isFirst
findPrev:   
    mov ecx,dword[first]
    cmp dword[ecx+1],ebx
    jz found
    mov ecx,dword[ecx+1]
    mov dword[first],ecx
    jmp findPrev


found:      
    mov ebx,dword[prev]
    mov dword[temp],ebx
    pushad
    call freeList
    popad
    mov ecx,dword[first]
    mov dword[ecx+1],0
    jmp finishZeroes


isFirst:
    mov ebx,dword[ebx+1]
    cmp ebx,0
    jz finishZeroes
    mov dword[temp],ebx
    pushad
    call freeList
    popad
    mov ebx,dword[first]
    mov dword[ebx+1],0
    
finishZeroes:
    mov esp, ebp	
    pop ebp
    ret


getStackSize:
    ;check if there is an ardument of size (argc>1)
    mov ecx, dword [esp+8]    
    mov esi, dword [esp+12]      ; esi = argv
    cmp ecx, 1
    jz stackSize5

    ;if so - put the arg in [stackSize]
    add esi, 4          ;the size is the argument in argv[1]
    mov ebx, dword [esi]

    mov eax,0
	mov edx,16
	ConvertAsciiNumCharToNumber:

        cmp byte [ebx], '9'
        jg convertCharToVal
        sub byte [ebx], '0'     ;make '0' equal 0
        jmp compute 

        convertCharToVal:
        sub byte [ebx], '7'     ;make 'A' equel 10
        
        compute:
        mul edx
        movzx edx, byte [ebx]
        add eax,edx
        mov edx,16
        inc ebx      	    		
        cmp byte [ebx], 0   			
        jnz ConvertAsciiNumCharToNumber  
                          	 	
	
	;at this point the number is in eax

    mulForSize:
    mov edx, 4
    mul edx
    mov [stackSize], eax

    sub esi, 4
    jmp retFromSize
    
    ;else - stackSize = 5
    stackSize5:
    jmp retFromSize

checkDebug:
    mov ecx, dword [esp+8]    
    mov esi, dword [esp+12]     ; esi = argv
    cmp ecx, 2                  ;if so, there is no debug flag
    jle retFromDebugCheck

    ;if argc>2 - there may be a debug flag
    add esi, 8         ;the size is the argument in argv[2]
    mov ebx, dword [esi]

    cmp byte [ebx], '-'
    jnz retFromDebugCheck
    cmp byte [ebx+1], 'd'
    jnz retFromDebugCheck
    mov dword [debug], 1        ;set debug=1
    jmp retFromDebugCheck