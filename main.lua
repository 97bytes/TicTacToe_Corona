--
-- Este programa implementa el juego TicTacToe (3 en línea) en Corona para jugar
-- contra el ordenador. Es una prueba de concepto. 
-- La aplicación se ha probado solamente en el simulador iPhone de Corona SDK (320x480px).
-- Gabriel Casarini
--

local widget = require "widget"
local seed = os.time();
math.randomseed( seed )

-- **************
-- DECLARACIONES
-- **************

local board = {0,0,0,0,0,0,0,0,0}   -- Estado del tablero
local computerPlayerId = 1
local userPlayerId = 2
local turnPlayerId = userPlayerId   -- Guarda el ID del jugador que tiene el turno de juego

boardX = 10         -- Origen de coordenadas para posicionar las fichas
boardY = 150
cellImages = {}     -- imagénes de las fichas del tablero
statusMessage = nil -- Mensaje que se muestra en la parte superior

-- *******************
-- GESTIÓN DE EVENTOS
-- *******************

--
-- Este handler procesa los eventos de la celdas del tablero
--
local onCellTouchListener = function( event )
	if ("ended" == event.phase and turnPlayerId == userPlayerId) then
		local index = event.target.id
		board[index] = userPlayerId
		nextTurn()
	end
	return true
end

--
-- Este handler es invocado cuando el usuario pulsa el botón del juego
-- para comenzar, reiniciar o volver a jugar
--
local function onButtonEvent( event )
    local btn = event.target
    if event.phase == "release" then
		btn:setLabel("Reiniciar partida")
		startGame()
	end
end


-- **********************************
-- FUNCIONES AUXILIARES PARA DEPURAR
-- **********************************

function printBoard(boardState)
	io.write("Board: ")
	for i=1,8 do
		io.write(boardState[i], ",")
	end
	io.write(boardState[9])
	print()
end    

function printMoves(moves)
	print("      Cell     Weight")
	for i=1,#moves do
		print(i, moves[i].targetCell, moves[i].weight)
	end
end


-- ****************************
-- CONTROL DEL FLUJO DEL JUEGO
-- ****************************

-- 
-- Reinicializa el estado del juego.
-- Notar que debemos ocultar el grupo de las notas, aunque sea necesario hacerlo la primera vez! 
-- Otra forma mejor, sin usar un flag?
--
function startGame()
	instructionsGroup.isVisible = false
	board = {0,0,0,0,0,0,0,0,0}
	if(cellImages ~= nil) then
		cleanBoard(cellImages)
	end
	cellImages = displayBoard(board)
	-- Elegir al azar el jugador que inicia la partida
	lucky = math.random(2)
	if(lucky == 1) then
		turnPlayerId = computerPlayerId
		statusMessage.text = "Yo comienzo..."
		timer.performWithDelay( 500, computerPlays )
	else 
		turnPlayerId = userPlayerId
		statusMessage.text = "Tu comienzas. Elige una celda."
	end
end

--
-- Carga las imágenes de las celdas en el tablero. El estado del tablero
-- llega en una tabla (!!!). Las celdas vacías se registran para recibir eventos
-- cuando el usuario las toca.
-- Notar que debemos retornar una tabla con las imágenes, para que luego puedan
-- eliminarse. Una forma mejor de hacerlo?
--
function displayBoard(boardState)
	local images = {}
	local cellSize = 103
	for i=0,2 do
		for j=0,2 do
			local x = boardX + 2 + j * cellSize
			local y = boardY + 2 + i * cellSize
			local index = i * 3 + j + 1
			if(boardState[index] == 1) then 
				cellImage = display.newImage("player1.png", x, y)
			else if(boardState[index] == 2) then
					cellImage = display.newImage("player2.png", x, y)
				else 
					cellImage = display.newImage("empty.png", x, y)
					cellImage:addEventListener( "touch", onCellTouchListener )
				end
			end
			cellImage.id = index
			images[index] = cellImage
		end
	end
	return images
end

--
-- Elimina las imágenes del tablero.
--
function cleanBoard(images)
	for i=1,#images do
		images[i]:removeSelf()
	end
end

--
-- Genera y retorna una copia de la tabla que guarda el estado del tablero de juego
--
function cloneBoard(boardState)
	local clone = {}
	for i=1,#boardState do
		clone[i] = boardState[i]
	end
	return clone
end

--
-- Comprueba si un jugador ha ganado la partida. Recibe el ID del jugador y el estado del tablero.
-- Retorna una tabla con 3 elementos: {isWinner=..., cells={...}}
--   isWinner: vale true si el jugador ha ganado; false en caso contrario
--   cells: índices de las celdas que forma la línea ganadora, o {} si el jugador no es ganador
--
function checkIsWinner(playerId, boardState)
	-- comprobar líneas horizontales
	for i=1,7,3 do
		if(boardState[i] == playerId and boardState[i+1] == playerId and boardState[i+2] == playerId) then
			return {isWinner=true, cells={i, i+1, i+2}}
		end
	end
	-- comprobar líneas verticales
	for i=1,3 do
		if(boardState[i] == playerId and boardState[i+3] == playerId and boardState[i+6] == playerId) then
			return {isWinner=true, cells={i, i+3, i+6}}
		end
	end
	-- comprobar líneas diagonales
	if(boardState[1] == playerId and boardState[5] == playerId and boardState[9] == playerId) then
		return {isWinner=true, cells={1, 5, 9}}
	end
	if(boardState[3] == playerId and boardState[5] == playerId and boardState[7] == playerId) then
		return {isWinner=true, cells={3, 5, 7}}
	end
	-- No es ganador!
	return {isWinner=false, cells={}}
end

--
-- Comprueba si el juego ha terminado y retorna una tabla de la forma {isOver=..., playerId=..., cells=...}
--    isOver: vale true si el juego ha terminado
--    playerId: si hay una ganador, es el ID del jugador. Si es empate, vale 0
--    cells: una tabla con las celdas que forman la línea ganadora
-- Notar que el juego puede terminar con un ganador o en empate (ninguno gana). Por ello hay que analizar
-- si el otro jugador todavía tiene posibilidades de ganar.
--
function checkGameOver(boardState, currentPlayerId, opponentPlayerId)
	local winnerCheck = checkIsWinner(currentPlayerId, boardState)
	if(winnerCheck.isWinner) then
		return {isOver=true, playerId=currentPlayerId, cells=winnerCheck.cells}
	end
	-- Analizar movimientos para saber si el oponente aún puede ganar
	opponentMoves = {evalVerticalLine(1, boardState, opponentPlayerId, currentPlayerId), 
		evalVerticalLine(2, boardState, opponentPlayerId, currentPlayerId), 
		evalVerticalLine(3, boardState, opponentPlayerId, currentPlayerId),
		evalHorizontalLine(1, boardState, opponentPlayerId, currentPlayerId), 
		evalHorizontalLine(4, boardState, opponentPlayerId, currentPlayerId), 
		evalHorizontalLine(7, boardState, opponentPlayerId, currentPlayerId),
		evalBackDiagonalLine(1, boardState, opponentPlayerId, currentPlayerId), 
		evalForwardDiagonalLine(3, boardState, opponentPlayerId, currentPlayerId), 
		blockOpponent(boardState, opponentPlayerId, currentPlayerId)}
	table.sort(opponentMoves, 
        function(m1,m2)
            return m1.weight < m2.weight
        end
    )
    local move = opponentMoves[1]
    if(move.targetCell > -1) then
    	return {isOver=false, playerId=0, cells={}} 
    end
    -- Empate porque ninguno tiene posibilidades de ganar
   	return {isOver=true, playerId=0, cells={}} 
end

--
-- Esta función gestiona los turnos entre los 2 jugadores y controla si el juego ha terminado.
-- Notar que usamos un 'timer' para introducir una espera cuando juega el ordenador
-- Otra forma mejor de hacer esto?
--
function nextTurn()
	cleanBoard(cellImages)
	cellImages = displayBoard(board)
	if(turnPlayerId == userPlayerId) then
		local gameOverCheck = checkGameOver(board, userPlayerId, computerPlayerId)
		if(gameOverCheck.isOver) then
			gameOver(gameOverCheck)
		else
			turnPlayerId = computerPlayerId
			statusMessage.text = "Es mi turno..."
			timer.performWithDelay( 500, computerPlays )
		end
	else
		local gameOverCheck = checkGameOver(board, computerPlayerId, userPlayerId)
		if(gameOverCheck.isOver) then
			gameOver(gameOverCheck)
		else
			turnPlayerId = userPlayerId
			statusMessage.text = "Es tu turno. Elige una celda libre."
		end
	end
end

--
-- El juego ha terminado y hay que actualizar el mensaje y provocar el efecto de temblor (shake) en 
-- las celdas que forman la línea ganadora.
-- En 'params' están todos los valores necesarios:
--    playerId: es el ID del jugador que ganó o 0 si es empate
--    cells: los índices de las celdas que forma la línea ganadora
-- Nótese que las imágenes tiemblan de forma diferente para cada jugador: la X se mueve menos que la O
function gameOver(params)
	turnPlayerId = -1
	local winnerId = params.playerId
	if(winnerId == userPlayerId) then
		local cells = params.cells
		images = {cellImages[cells[1]], cellImages[cells[2]], cellImages[cells[3]]}
		shake(images[1], 15)
		shake(images[2], 15)
		shake(images[3], 15)
		statusMessage.text = "Felicidades! Has ganado la partida."
	elseif(winnerId == computerPlayerId) then
		statusMessage.text = "La partida ha terminado. Y has perdido"
		local cells = params.cells
		images = {cellImages[cells[1]], cellImages[cells[2]], cellImages[cells[3]]}
		shake(images[1], 4)
		shake(images[2], 4)
		shake(images[3], 4)
	else
		statusMessage.text = "La partida ha terminado en empate"
	end
	button:setLabel("Nueva partida")
end


-- ***********************************
-- ALGORITMO DEL ORDENADOR PARA JUGAR
-- ***********************************

--
-- Es el turno del ordenador. Elegimos la celda analizando las posibilidades de ganar proyectando 
-- líneas sobre el tablero. El algoritmo consiste en:
--   1) Calcular la cantidad de pasos requeridos para formar cada línea y además, si podemos
--      bloquear al oponente.
--   2) Se ordenan los valores anteriores y se obtiene la celda correspondiente.
-- Luego, cambiamos el turno para el otro jugador
--
function computerPlays()
	local moves = {evalVerticalLine(1, board, computerPlayerId, userPlayerId), 
		evalVerticalLine(2, board, computerPlayerId, userPlayerId), 
		evalVerticalLine(3, board, computerPlayerId, userPlayerId),
		evalHorizontalLine(1, board, computerPlayerId, userPlayerId), 
		evalHorizontalLine(4, board, computerPlayerId, userPlayerId), 
		evalHorizontalLine(7, board, computerPlayerId, userPlayerId),
		evalBackDiagonalLine(1, board, computerPlayerId, userPlayerId), 
		evalForwardDiagonalLine(3, board, computerPlayerId, userPlayerId), 
		blockOpponent(board, computerPlayerId, userPlayerId), 
		randomCell(board)}

	table.sort(moves, 
        function(m1,m2)
            return m1.weight < m2.weight
        end
    )

	local nextMove = moves[1]
	local targetCell = nextMove.targetCell
	board[targetCell] = computerPlayerId
	nextTurn()
end

-- 
-- Esta estrategia retorna una celda libre elegida al azar.
-- El peso es 2.2, para que tenga menos prioridad que las estrategias de bloqueo
-- del oponente y que las estrategias que pueden formar una línea en menos de 3 pasos
-- 
function randomCell(boardState)
	freeCells = {}
	for i=1,9 do
		if(boardState[i] == 0) then
			table.insert(freeCells, i)
		end
	end
	if(#freeCells == 0) then
		return {targetCell=-1, weight=100}
	end	
	local i = math.random(#freeCells)
	return {targetCell=freeCells[i], weight=2.2}
end

-- 
-- Esta estrategia analiza si es posible bloquear al oponente en 1 solo paso. 
-- Si es así, retorna la celda que debería elegirse. Si no, retorna un movimiento inválido.
-- 
function blockOpponent(boardState, currentPlayerId, opponentPlayerId)
	local clone = cloneBoard(boardState)
	for i=1,9 do
		if(clone[i] == 0) then
			clone[i] = opponentPlayerId
			winnerCheck = checkIsWinner(opponentPlayerId, clone)
			if(winnerCheck.isWinner) then
				return {targetCell=i, weight=1.1}
			end
			clone[i] = 0
		end
	end
	return {targetCell=-1, weight=100} -- Movimiento no válido!
end

-- 
-- Esta estrategia analiza si es posible formar una línea diagonal. 
-- Si es así, retorna la celda que debería elegirse y el peso es la cantidad de pasos para
-- formar la línea. Si no, retorna un movimiento inválido.
--   --X
--   -X-
--   X--
--
function evalForwardDiagonalLine(origin, boardState, currentPlayerId, opponentPlayerId) 
	return evalLine(origin, origin+4, 2, boardState, currentPlayerId, opponentPlayerId)
end

-- 
-- Esta estrategia analiza si es posible formar una línea diagonal. 
-- Si es así, retorna la celda que debería elegirse y el peso es la cantidad de pasos para
-- formar la línea. Si no, retorna un movimiento inválido.
--   X--
--   -X-
--   --X
--
function evalBackDiagonalLine(origin, boardState, currentPlayerId, opponentPlayerId) 
	return evalLine(origin, origin+8, 4, boardState, currentPlayerId, opponentPlayerId)
end

-- 
-- Esta estrategia analiza si es posible formar una línea vertical. 
-- Si es así, retorna la celda que debería elegirse y el peso es la cantidad de pasos para
-- formar la línea. Si no, retorna un movimiento inválido.
--   -X-
--   -X-
--   -X-
--
function evalVerticalLine(origin, boardState, currentPlayerId, opponentPlayerId) 
	return evalLine(origin, origin+6, 3, boardState, currentPlayerId, opponentPlayerId)
end

-- 
-- Esta estrategia analiza si es posible formar una línea horizontal. 
-- Si es así, retorna la celda que debería elegirse y el peso es la cantidad de pasos para
-- formar la línea. Si no, retorna un movimiento inválido.
--   ---
--   XXX
--   ---
--
function evalHorizontalLine(origin, boardState, currentPlayerId, opponentPlayerId) 
	return evalLine(origin, origin+2, 1, boardState, currentPlayerId, opponentPlayerId)
end

-- 
-- Analiza si es posible formar una línea recta en el tablero.
--
function evalLine(origin, ending, inc, boardState, currentPlayerId, opponentPlayerId) 
	local targetCell = -1
	local weight = 3
	for i=origin,ending,inc do
		if(boardState[i] == opponentPlayerId) then
			targetCell = -1
			weight = 100
			return {targetCell=targetCell, weight=weight}
		end
		if(boardState[i] == 0 and targetCell == -1) then
			targetCell = i
		end
		if(boardState[i] == currentPlayerId) then
			weight = weight - 1
		end
	end
	if(targetCell == -1) then
		weight = 100
	end
	return {targetCell=targetCell, weight=weight}
end

-- ********************
-- PRESENTACIÓN VISUAL
-- ********************

--
-- Inicializar la pantalla
-- Existe una manera mejor de escribir esto?
--
function initDisplay()
	background = display.newImage("background.jpg", 0, 0)
	button = widget.newButton{
		default = "button.png",
		over = "button_pressed.png",
		label = "Comenzar",
	    fontSize = 13,
	    yOffset = -2,
		labelColor = { default={ 255 }, over={ 255 } },
		onEvent = onButtonEvent
	}

	button.x = 68
	button.y = 42

	cellImages = displayBoard(board)
	statusMessage = display.newText( "", 0, 0, native.systemFont, 15 )
	statusMessage:setTextColor( 255,255,255 )
	local centeredMessageGroup = display.newGroup()
	centeredMessageGroup.x = display.contentWidth * 0.5
	centeredMessageGroup.y = 100
	centeredMessageGroup:insert( statusMessage, true )

	textLine1 = display.newText( "Pulsa 'Comenzar' para jugar", 0, 0, native.systemFont, 16 )
	textLine1:setTextColor( 255,255,255 )
	textLine2 = display.newText( ": Tu símbolo y color", 42, 35, native.systemFont, 16 )
	textLine2:setTextColor( 255,255,255 )
	textLine3 = display.newText( ": iPhone (adversario)", 42, 70, native.systemFont, 16 )
	textLine3:setTextColor( 255,255,255 )
	cellImage1 = display.newImage("player2.png", 0, 0)
	cellImage1.height = 37
	cellImage1.width = 37
	cellImage1.xOrigin = 16
	cellImage1.yOrigin = 44
	cellImage2 = display.newImage("player1.png", 0, 90)
	cellImage2.height = 40
	cellImage2.width = 40
	cellImage2.xOrigin = 16
	cellImage2.yOrigin = 82
	instructionsGroup = display.newGroup()
	instructionsGroup.x = 55
	instructionsGroup.y = 200
	instructionsGroup:insert( textLine1, false )
	instructionsGroup:insert( textLine2, false )
	instructionsGroup:insert( textLine3, false )
	instructionsGroup:insert( cellImage1, false )
	instructionsGroup:insert( cellImage2, false )
end

--
-- Mueve la imagen para que parezca que vibra o tiembla.
-- El valor de 'rotValue' define cuánto rota
--
function shake(image, rotValue)
    local ox = image.x
    local oy = image.y
    function image:timer(e) 
        local t = 25
        self:setReferencePoint(display.CenterReferencePoint)
        transition.to(self, { time=t, rotation=rotValue, transition=easing.outExpo, onComplete=doNothing})
		transition.to(self, { time=t, delay=t, rotation=-1 * (rotValue-2), transition=easing.inExpo, onComplete=doNothing})
        transition.to(self, { time=1000, delay=1000, rotation=0, transition=easing.outExpo, onComplete=doNothing})
    end
    timer.performWithDelay(150, image, 10)
end

initDisplay()