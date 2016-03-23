//CHECKERS, by Abiyaz Chowdhury, Version 1.01, 9/22/2015
//global game variables
import java.util.*;
int[] board = new int[64]; //stores the board
int turn = 1; //stores the turn
int edit_mode = 0;  //0 = game mode, 1 = edit board
int[] user_move = {-1, -1}; //user submission, the first entry is the piece to be moved, the second piece is the destination (or target of a capture)
ArrayList<ArrayList<Integer>> current_legal_moves = new ArrayList(); //specifies the legal moves currently possible
ArrayList<Integer> current_legal_moves2 = new ArrayList(); //stores the legal moves currently possible (only used if the current move is part of a multi-capture move)
int global_winner = 0; //stores who has won the current game
int must_capture = -1; //specifies which piece must capture (if it is part of a multi-capture move);
int must_capture2 = -1;
int count;
int pruned_paths;
int max_depth = 7;
int depth = max_depth;
int time = 0;
int infinity = 9999;
int time_limit = 1;
//int heuristic = -1;
//int[] mini_board = new int[64];
PFont myFont;
ArrayList<ArrayList<Integer>> AI_move = new ArrayList(); //stores the AI's best move, is evaluated only when AI is clicked

void setup(){
  size(1200, 1200);
  myFont = createFont("Verdana", 12);
  textFont(myFont, 12);
  reset_board(board);
  //custom_board(board);
  //clear_board(mini_board);
}

void draw() {
  background(0);
  display_board();
  //display_mini_board();
  display_text();
  if ((user_move[1] != -1)&&(edit_mode == 0)&&(global_winner == 0)) { //consider a move only if the game is not in edit move, no one has won, and the user actually submitted a complete move
    if  ((must_capture == -1)||(must_capture == user_move[0])) {  //if the user must capture with a different piece, do not accept the move
      println("Move submitted: " + user_move[0] + " " + user_move[1]); 
      int is_capture_move = 0; //is it a capture?
      int destination = user_move[1]; //stores the destination of the moving (or capturing) piece
      if ((abs(abs(user_move[1]-user_move[0])-16)==2)&&(board[user_move[0]+(user_move[1]-user_move[0])/2] != 0)) {
        is_capture_move = 1; //if the user made a capture by selecting the square to jump to, it is a capture
        //println("it is a capture with second part of move as destination");
        destination = user_move[0]+(user_move[1]-user_move[0])/2;
      } else if ((abs(abs(user_move[1]-user_move[0])-8) == 1)&&(board[user_move[1]] != 0)) {
        is_capture_move = 1; //if the user made a capturee by selecting the piece to capture, it is a capture
        //println("it is a capture with second part of move as capture target");
      }
      if (((is_capture_move == 1)||(must_capture == -1))&&(is_legal_move(board, user_move[0], destination, turn))) {
        println("Legal move submitted");
        ArrayList<Integer> move = new ArrayList();
        move.add(user_move[0]);
        move.add(destination);
        int piece = board[user_move[0]];
        int new_position = process_move(board, move);
        user_move[0] = user_move[1] = -1;
        if ((is_capture_move == 0) || (board[new_position] == 10*piece) || (can_capture(board, new_position).size() <= 0)) { //the turn is over only if the piece moved or if it captured, but cannot capture anymore (or if it promoted)
          turn*= -1;
          must_capture = -1;
          current_legal_moves = legal_moves(board, turn);
          global_winner = winner(board);
        } else {
          must_capture = new_position;
          current_legal_moves2 = can_capture(board, new_position);
        }
      } else {
        user_move[0] = user_move[1] = -1;
      }
    } else {
      user_move[0] = user_move[1] = -1;
    }
  }
}

ArrayList<ArrayList<Integer>> legal_moves(int[] board, int player_color) {
  //This function generates the set of legal moves for a given combination of a board and player color. It first generates a capture tree to indicate the possible sequence of captures, and then if no captures are possible, it generates the set of possible movements
  //promotions of the pieces. player_color = 1 if white, -1 if black
  //println("Calling legal moves");
  ArrayList<ArrayList<Integer>> legal = new ArrayList();
  //CAPTURE TREE
  List<ArrayList> stack = new Stack();
  stack.add(new ArrayList());
  int[] tempboard = new int[64];
  int current_position = 0;
  int start_time = millis();
  while (stack.size() > 0) {
    if (millis()-start_time > 1000) {
      break;
    }
    int promotion = 0;
    System.arraycopy( board, 0, tempboard, 0, 64 );
    ArrayList<Integer> move = stack.remove(stack.size()-1);
    //print("Processing move: ");
    //print_move(move);
    if (move.size() > 0) {
      //println("Interal or leaf node, processing a possibly multi-capture move");
      int piece = tempboard[move.get(0)];
      current_position = process_move(tempboard, move);
      //println("Current position: " + current_position);
      if (tempboard[current_position] == 10*piece) {
        promotion = 1;
      }
      //println("Processed the above move");
    }
    if ((move.size() != 0) && ((promotion == 1)||(can_capture(tempboard, current_position).size() == 0))) { //if we are at a leaf node
      //println("Leaf node");
      legal.add(move);
    } else {
      if (move.size() == 0) { //if we are at the root node
        //println("Legal moves: Root node of capture tree");
        for (int i = 0; i < 64; i ++) {//for each friendly piece, we determine what captures it can make
          int piece_color = 0;
          if (tempboard[i] != 0) {
            piece_color = abs(tempboard[i])/tempboard[i];
          }
          //println("piece_color: " + piece_color + " player_color: " + player_color);
          if (piece_color == player_color) { //if the piece is friendly
            ArrayList<Integer> captures = can_capture(tempboard, i); //what captures can it make?
            if (captures.size() > 0) { //if it can make a capture
              for (int j = 0; j < captures.size(); j++) {
                ArrayList<Integer> captures2 = new ArrayList(); 
                captures2.add(i);
                captures2.add(captures.get(j));
                //println("Currently at root node. Adding move to stack: ");
                //print_move(captures2);
                stack.add(captures2);
              }
            }
          }
        }
      } else {  //if we are at an internal node
        ArrayList<Integer> captures = can_capture(tempboard, current_position);
        if (captures.size() > 0) {
          for (int j = 0; j < captures.size(); j++) {
            ArrayList<Integer> captures2 = new ArrayList();
            for (int k = 0; k < move.size(); k++) {
              captures2.add(move.get(k));
            }
            captures2.add(captures.get(j));
            //println("Currently at internal node. Adding move to stack: ");
            //print_move(captures2);
            stack.add(captures2);
          }
        }
      }
    }
  }
  //if, at this point, no captures are possible, then we see if movement/promotion is possible. If not, no move is possible.
  if (legal.size() > 0) {
    //print_legal_moves(legal);
    //println("End of legal moves function. Captures are possible, so movement is not considered.");
    return legal;
  }
  //println("Legal move function: empty capture tree, checking for movement/promotion");
  for (int i = 0; i < 64; i++) {
    int piece_color = 0;
    if (board[i] != 0) {
      piece_color = abs(board[i])/board[i];
    }
    if (piece_color == player_color) {
      if ((abs(board[i]) == 10)||(piece_color == 1)) { //if the piece is a king or if the piece is white, test for upward capture
        if ( (i+9<64) && (i%8 < 7) && (board[i+9] == 0)) { //move up-right
          ArrayList move = new ArrayList();
          move.add(i);
          move.add(i+9);
          legal.add(move);
        }
        if ( (i+7<64) && (i%8 > 0) && (board[i+7] == 0)) { //move up-left
          ArrayList move = new ArrayList();
          move.add(i);
          move.add(i+7);
          legal.add(move);
        }
      }
      if ((abs(board[i]) == 10)||(piece_color == -1)) { //if the piece is a king or if the piece is black, test for upward capture
        if ( (i-7>-1) && (i%8 < 7) && (board[i-7] == 0)) { //move down-right
          ArrayList move = new ArrayList();
          move.add(i);
          move.add(i-7);
          legal.add(move);
        }
        if ( (i-9>-1) && (i%8 > 0) && (board[i-9] == 0)) { //move down-left
          ArrayList move = new ArrayList();
          move.add(i);
          move.add(i-9);
          legal.add(move);
        }
      }
    }
  }
  //print_legal_moves(legal);
  //println("End of legal moves function. No captures are possible.");
  return legal;
}

int winner(int[] board) {
  //-1 is black win, 1 is white win, 0 is game in progress
  int no_white = 1;
  int no_black = 1;
  for (int i = 0; i < 64; i++) {
    if (board[i] > 0) {
      no_white = 0;
    } else if (board[i] < 0) {
      no_black = 0;
    }
  }
  if (no_white == 1) {
    return -1;
  } else if (no_black == 1) {
    return 1;
  }
  //println("Winner function: checking if white has any legal moves");
  ArrayList<ArrayList<Integer>> legal = legal_moves(board, 1);
  if ((legal.size() == 0)&&(turn == 1)) {
    return -1;
  }
  //println("Winner function: checking if black has any legal moves");
  legal = legal_moves(board, -1);
  if ((legal.size() == 0)&&(turn == -1)) {
    return 1;
  }
  return 0;
}

void display_board() {
  for (int i = 0; i < 64; i++) {
    stroke(255);
    int c = ((i%8)+(int)(i/8))%2;
    fill(c*255);
    int x = 200+(i%8)*50;
    int y = 550-(int)(i/8)*50;
    rect(x, y, 50, 50);
    if (board[i] != 0) {
      display_piece(x, y, c, board[i]);
    }
    fill(255*(1-c));
    text(i, x+33, y+12);
  }
}


/*
void display_mini_piece(int x, int y, int square, int piece) {
 int c = (abs(piece)/piece+1)/2;
 fill(c*255);
 stroke((1-square)*255);
 switch (piece = abs(piece)) {
 case 1:
 ellipse(x+12, y+12, 15, 15);
 break;
 case 10:
 beginShape();
 vertex(x+12, y+2);
 vertex(x+2, y+12);
 vertex(x+12, y+22);
 vertex(x+22, y+12);
 vertex(x+12, y+2);
 endShape();
 break;
 }
 }
 
 void display_mini_board() {
 for (int i = 0; i < 64; i++) {
 stroke(255);
 int c = ((i%8)+(int)(i/8))%2;
 fill(c*255);
 int x = 800+(i%8)*25;
 int y = 400-(int)(i/8)*25;
 rect(x, y, 25, 25);
 if (mini_board[i] != 0) {
 display_mini_piece(x, y, c, mini_board[i]);
 }
 fill(255*(1-c));
 }
 }
 
 */
void display_piece(int x, int y, int square, int piece) {
  int c = (abs(piece)/piece+1)/2;
  fill(c*255);
  stroke((1-square)*255);
  switch (piece = abs(piece)) {
  case 1:
    ellipse(x+25, y+25, 30, 30);
    break;
  case 10:
    beginShape();
    vertex(x+25, y+5);
    vertex(x+5, y+25);
    vertex(x+25, y+45);
    vertex(x+45, y+25);
    vertex(x+25, y+5);
    endShape();
    break;
  }
}

void display_text() {
  fill(0);
  stroke(255);
  rect(100, 200, 75, 50);
  rect(100, 260, 75, 50);
  rect(200, 700, 75, 50);
  rect(300, 700, 75, 50);
  rect(400, 700, 75, 50);
  rect(500, 700, 75, 50);
  if (edit_mode == 0) {
    fill(255);
    text("EDIT", 125, 225);
    text("AI", 125, 285);
    if ((AI_move.size() > 0)&&(AI_move.get(0).get(0)!=-1)) {
      text(AI_move.get(0).get(0), 100, 345);
      if (AI_move.get(1).size() > 0) {
        text(AI_move.get(1).get(0), 100, 360);
        for (int i = 1; i < AI_move.get(1).size(); i++) {
          text("to " + AI_move.get(1).get(i), 100+35*(i-1)+20, 360);
        }
        text("Depth: " + depth, 100, 375);
        text("Time (seconds): ", 100, 390);
        text((float)time/1000, 100, 405);
      }
    }
    if (turn == 1) {
      text("White to move.", 100, 100);
      text("Legal moves (for white):", 625, 225);
    } else if (turn == -1) {
      text("Legal moves (for black):", 625, 225);
      text("Black to move.", 100, 100);
    }
    if (must_capture == -1) {
      for (int i = 0; i < current_legal_moves.size(); i++) {
        text(current_legal_moves.get(i).get(0), 625, 240+i*15);
        for (int j = 1; j < current_legal_moves.get(i).size(); j++) {
          text("to " + current_legal_moves.get(i).get(j), 625+35*(j-1)+20, 240+i*15);
        }
      }
    } else {
      for (int i = 0; i < current_legal_moves2.size(); i++) {
        text(must_capture, 625, 240+i*15);
        text("to " + current_legal_moves2.get(i), 645, 240+i*15);
      }
    }
  } else {
    fill(255);
    text("BACK TO", 105, 225);
    text("GAME", 105, 240);
    fill(0);
    stroke(255);
    rect(100, 320, 75, 50);
    rect(100, 380, 75, 50);
    fill(255);
    text("CLEAR", 105, 285);
    text("BOARD", 105, 300);
    text("RESET", 105, 345);
    text("BOARD", 105, 360);
    text("SWITCH", 105, 405);
    text("TURN", 105, 420);
    if (turn == 1) {
      text("EDIT MODE (with white to move).", 100, 100);
    } else {
      text("EDIT MODE (with black to move).", 100, 100);
    }
  }
  fill(255);
  text("Current AI Time limit (seconds): " + time_limit, 200, 670);
  text("Use the buttons below to control the AI's time limit. ", 200, 685);
  text("+10s ", 225, 725);
  text("+1s ", 325, 725); 
  text("-10s ", 425, 725);
  text("-1s ", 525, 725);
  text(user_move[0] + " " + user_move[1], 100, 150);
  if (global_winner == 1) {
    textFont(myFont, 20);
    text("WHITE WINS!", 400, 150); 
    textFont(myFont, 12);
  } else if (global_winner == -1) {
    textFont(myFont, 20);
    text("BLACK WINS!", 400, 150); 
    textFont(myFont, 12);
  }
}

int process_move(int[] board, ArrayList<Integer> move) {
  //given a board, this function processes the move on the board, updating it to reflect the move being played. The entries of move correspond to {piece, destination}. A destination that is occupied implies a capture, and must be dealt with accordingly.
  //print("Process_move function: ");
  //print_move(move);
  int piece = board[move.get(0)];
  int piece_color = abs(piece)/piece;
  if (board[move.get(1)] != 0) {  //if the move is a capture
    int next_move = move.get(0);
    for (int i = 1; i < move.size(); i++) {
      int difference = move.get(i)-next_move;
      if (abs(abs(difference)-8) == 1) {
        if (((next_move+2*difference)/8 == (((difference/abs(difference))*7+7)/2))&&(abs(piece)==1)) {
          board[next_move+2*difference] = 10*board[next_move];
          piece *= 10;
        } else {
          board[next_move+2*difference] = board[next_move];
        }
        board[move.get(i)] = 0;
        board[next_move] = 0;
        next_move = next_move+2*difference;
      }
    }
    return next_move;
  } else if (((move.get(1)/8) == (7*(piece_color+1)/2))&&(abs(piece)== 1) ) { //if the move is a promotion
    board[move.get(1)] = 10*board[move.get(0)];
    board[move.get(0)] = 0;
    return move.get(1);
  } else { //if the move is just a regular move
    board[move.get(1)] = board[move.get(0)];
    board[move.get(0)] = 0;
    return move.get(1);
  }
}

ArrayList<Integer> can_capture(int[] board, int position) {
  //given a board and a piece on the board (specified by its position on the board), can that piece make an immediate capture? This function returns the list of captures (each stored as a vector of ints).
  int piece = board[position];
  int piece_color = abs(piece)/piece;
  ArrayList<Integer> captures = new ArrayList();
  if ((piece_color == 1)||(abs(piece) == 10)) { //if the piece is a king or if the piece is white, test for upward capture
    if ( (position+18<64) && (position%8 < 6) && (board[position+18] == 0) && (board[position+9]!=0)&&(abs(board[position+9])/board[position+9] == -piece_color)) { //capture up-right
      captures.add(position+9);
    }
    if ( (position+14<64) && (position%8 > 1) && (board[position+14] == 0) && (board[position+7]!=0)&&(abs(board[position+7])/board[position+7] == -piece_color)) { //capture- up-left
      captures.add(position+7);
    }
  }
  if ((piece_color == -1)||(abs(piece) == 10)) { //if the piece is a king or if the piece is black, test for downward capture
    if ( (position-14>-1) && (position%8 < 6) && (board[position-14] == 0) && (board[position-7]!=0)&&(abs(board[position-7])/board[position-7] == -piece_color)) {  //capture down-right
      captures.add(position-7);
    }
    if ( (position-18>-1) && (position%8 > 1) && (board[position-18] == 0) && (board[position-9]!=0)&&(abs(board[position-9])/board[position-9] == -piece_color)) {  //capture down-left
      captures.add(position-9);
    }
  }
  return captures;
}

void print_legal_moves(ArrayList<ArrayList<Integer>> array) {
  print("Printing legal moves ");
  for (int i = 0; i < array.size(); i++) {
    for (int j = 0; j < array.get(i).size(); j++) {
      print(array.get(i).get(j) + " ");
    }
    print("\t");
  }
  println();
}

void print_move(ArrayList<Integer> move) {
  for (int i = 0; i < move.size(); i++) {
    print(move.get(i) + " ");
  }
  println();
}

boolean is_legal_move(int[] board, int position, int destination, int player_color) {
  //println("Checking if move is legal for piece:  " + position + " " + destination + " " + player_color); 
  if (board[position] == 0) {
    return false;
  } else if (abs(board[position])/board[position] != player_color) {
    return false;
  } else {
    ArrayList<ArrayList<Integer>> legal_moves_set = legal_moves(board, player_color);
    for (int i = 0; i < legal_moves_set.size(); i++) {
      if ((legal_moves_set.get(i).get(0) == position)&&(legal_moves_set.get(i).get(1) == destination)) {
        return true;
      }
    }
  }
  return false;
}

void clear_board(int[] board) {
  for (int i = 0; i < 64; i++) {
    board[i] = 0;
  }
  turn = 1;
  global_winner = 0;
}

void reset_board(int []board) {
  for (int i = 0; i < 64; i++) {
    board[i] = 0;
  } 
  board[0] = board[2] = board[4] = board[6] = 1; 
  board[9] = board[11] = board[13] = board[15] = 1;
  board[16] = board[18] = board[20] = board[22] = 1;
  board[41] = board[43] = board[45] = board[47] = -1;
  board[48] = board[50] = board[52] = board[54] = -1;
  board[57] = board[59] = board[61] = board[63] = -1;
  turn = 1;
  user_move[0] = user_move[1]= -1;
  global_winner = 0;
  current_legal_moves = legal_moves(board, turn);
}

void custom_board(int []board) {
  for (int i = 0; i < 64; i++) {
    board[i] = 0;
  } 
  board[25] = board[18] = board[34] = 1; 
  board[36] = 10;
  board[16] = board[48] = board[61] = board[47] = -1;
  board[20] = board[9] = -10;
  turn = -1;
  user_move[0] = user_move[1]= -1;
  global_winner = 0;
  current_legal_moves = legal_moves(board, turn);
}

void mousePressed() {
  int x = mouseX/50-4;
  int y = 11-mouseY/50;
  if (edit_mode == 0) {
    if ((x>-1)&&(x<8)&&(y>-1)&&(y<8)) { //if the mouse is clicked within the board during game
      println("User clicked on: " + (y*8+x));
      if (user_move[0] == -1) { //if the user has not selected a piece to move
        if (board[y*8+x]*turn>0) { //if the piece belongs to the user
          user_move[0] = y*8+x; //select that piece for movement
        }
      } else { //if the user has selected a piece to move
        user_move[1] = y*8+x; //select the destination for the piece
      }
    } else if ((mouseX>100)&&(mouseX<175)&&(mouseY>260)&&(mouseY<310)) { //if the AI button is pressed
      count = 0;
      pruned_paths = 0;
      fill(255);
      println("Thinking...");
      time = millis();
      if ((must_capture == -1) && (current_legal_moves.size() == 1)) {
        println("Only one possible move. AI not used.");
        depth = 1;
        AI_move.add(new ArrayList());
        AI_move.add(new ArrayList());
        AI_move.get(0).add(heuristic(board));
        AI_move.set(1, current_legal_moves.get(0));
      } else if ((must_capture != -1) && (current_legal_moves2.size() == 1)) {
        println("Only one possible move due to forced capture with a piece involved in multi capture. AI not used.");
        depth = 1;
        AI_move = new ArrayList();
        AI_move.add(new ArrayList());
        AI_move.add(new ArrayList());
        AI_move.get(0).add(heuristic(board));
        AI_move.get(1).add(must_capture);
        AI_move.get(1).add(current_legal_moves2.get(0));
      } else {
        AI_move = new ArrayList();
        AI_move.add(new ArrayList());
        AI_move.get(0).add(-1);
        ArrayList<ArrayList<Integer>> temp = new ArrayList();
        temp.add(new ArrayList());
        temp.get(0).add(0);
        int stop = 0;
        //for (int i = 0; ((i<15)&&(temp.get(0).get(0)!= -1)&&(((turn == 1)&&((AI_move.get(0).get(0) < infinity)))||((turn == -1)&&((AI_move.get(0).get(0) > 0))))); i++) { //iterative deepening
        for (int i = 0; ((i<12)&&(stop == 0)&&((AI_move.get(0).get(0) != infinity)&&(AI_move.get(0).get(0) != 0))); i++) { //iterative deepening
          //println("Iterative deepening, depth: " + i);
          must_capture2 = must_capture;
          temp= minimax_alpha_beta(board, turn, i, 0, infinity);
          if (temp.get(0).get(0) > -1) { //temp starts with 0 and AI_move starts with -1, if the last minimax is better than AI_move, update AI_move.
            //println("Accepted this depth.");
            AI_move = temp;
            //print_move(AI_move.get(1));
          } else {
            stop = 1;
          }
          depth = i;
        }
      }
      time = millis()-time;
      println("Searched (alpha-beta): " + count);
      println("Pruned paths: " + pruned_paths);
    }
  } else if (edit_mode == 1) {
    if ((mouseX>100)&&(mouseX<175)&&(mouseY>260)&&(mouseY<310)) { //if the clear board button is pressed
      clear_board(board);
    } else if ((mouseX>100)&&(mouseX<175)&&(mouseY>320)&&(mouseY<370)) { //if the reset board button is pressed
      reset_board(board);
    } else if ((mouseX>100)&&(mouseX<175)&&(mouseY>380)&&(mouseY<430)) { //if the switch turn button is pressed
      turn *= -1;
    } else if ((x>-1)&&(x<8)&&(y>-1)&&(y<8)) { //if the mouse is clicked within the board during edit mode
      println("User clicked on: " + (y*8+x));
      switch (board[y*8+x]) { //change the clicked pieces in the following way: empty square --> white pawn --> white king --> black pawn --> black king --> empty square
      case 0:
        board[y*8+x] = 1; 
        break;
      case 1:
        board[y*8+x] = 10;
        break;
      case 10:
        board[y*8+x] = -1;
        break;
      case -1:
        board[y*8+x] = -10;
        break;
      case -10:
        board[y*8+x] = 0;
        break;
      }
    }
  }
  if ((mouseX>100)&&(mouseX<175)&&(mouseY>200)&&(mouseY<250)) { //if edit button is pressed
    AI_move = new ArrayList();
    edit_mode = 1 - edit_mode; //switch mode
    user_move[0] = user_move[1] = -1; //reset user move
    must_capture = -1; //reset forced capture
    if (edit_mode == 0) {
      current_legal_moves = legal_moves(board, turn); //if edit mode is turned off, the winner is determined, and the legal moves for the current position are evaluated
      global_winner = winner(board);
    }
  } else if ((mouseY>700)&&(mouseY<750)) {
    if ((mouseX>200)&&(mouseX<275)) {
      time_limit += 10;
    } else if ((mouseX>300)&&(mouseX<375)) {
      time_limit += 1;
    } else if ((mouseX>400)&&(mouseX<475)) {
      time_limit -= 10;
      if (time_limit < 1) {
        time_limit = 1;
      }
    } else if ((mouseX>500)&&(mouseX<575)) {
      time_limit -= 1;
      if (time_limit < 1) {
        time_limit = 1;
      }
    }
  }
}


ArrayList<ArrayList<Integer>> minimax_alpha_beta(int[] board, int player_color, int depth, int alpha, int beta) { //best score, then best move
  count++;
  ArrayList<ArrayList<Integer>> result = new ArrayList();
  result.add(new ArrayList());
  result.add(new ArrayList());
  if (time_limit*1000-(millis()-time) < 3) {  //timer calculations, minimax will prematurely terminate if there is not enough time on the clock
    result.get(0).add(-1);
    return result;
  }
  if (depth == 0) { //minimax will immediately terminate if the max depth has been reached, i.e. the node is a leaf node
    result.get(0).add(heuristic(board));
    //println("heuristic result: " + result.get(0).get(0));
    return result;
  }
  ArrayList<ArrayList<Integer>> options = legal_moves(board, player_color); //collect all the legal moves in the given board
  if (options.size() == 0) { //if no legal moves are possible, the player has lost.
    result.get(0).add(heuristic(board));
    return result;
  }
  if (must_capture2 != -1) { //if a certain piece is forced to capture, legal moves must be updated.
    println("Must capture");
    must_capture2 = -1;
    for (int i = 0; i < options.size(); i++) {
      if (options.get(i).get(0) != must_capture) {
        options.remove(i);
        i--;
      }
    }
  }
  if (player_color == 1) {
    result.get(0).add(0);
  } else {
    result.get(0).add(infinity);
  }
  result.set(1, options.get(0));
  int stop = 0;
  int i;
  int j = 1;
  for (i = 0; (i < options.size())&&(stop == 0); i++) {
    //print_move(options.get(i));
    int[] tempboard = new int[64];
    System.arraycopy( board, 0, tempboard, 0, 64 );
    //println("Processing the above move on a temp board");
    process_move(tempboard, options.get(i));
    //output.println("");
    //output.print(" H " );
    //output.print(value);
    int value = minimax_alpha_beta(tempboard, -player_color, depth-1, alpha, beta).get(0).get(0);
    //println("Heuristic for this board: " + value);
    if (value == -1) {
      result.get(0).set(0, value);
      return result;
    }
    if ((value != 0)&&(value != infinity)) {
      value -= turn;
    }
    switch(player_color) {
    case 1:
      if (value > result.get(0).get(0)) {
        //mini_board = tempboard;
        result.get(0).set(0, value);
        result.set(1, options.get(i));
        alpha = value;
        if (value > beta) {
          stop = 1;
        }
      } else if (value == result.get(0).get(0)) {
        j++;
        if (((int)random(j)) == 1) {
          result.set(1, options.get(i));
          //mini_board = tempboard;
        }
      }
      break;
    case -1:
      if (value < result.get(0).get(0)) {
        //mini_board = tempboard;
        result.get(0).set(0, value);
        result.set(1, options.get(i));
        beta = value;
        if (value < alpha) {
          stop = 1;
        }
      } else if (value == result.get(0).get(0)) {
        j++;
        if (((int)random(j)) == 1) {
          result.set(1, options.get(i));
          // mini_board = tempboard;
        }
      }
      break;
    }
  }
  pruned_paths += (options.size()-i);
  return result;
}

int heuristic(int[] board) {
  int white_material = 0;
  int black_material = 0;
  int pawn = 10;
  int king = 14;
  int[] white_mean = {0, 0};
  int white_piece_count = 0;
  int[] black_mean = {0, 0};
  int black_piece_count = 0;
  int trap_bonus = 0;
  int winner = winner(board);
  if (winner == 1) {
    return infinity;
  } else if (winner == -1) {
    return 0;
  }
  for (int i = 0; i < 64; i++) {
    switch(board[i]) {
    case 1:
      white_material += (pawn+((i/8)*(king-pawn))/14);
      white_mean[0] += (i%8);
      white_mean[1] += (i/8);
      white_piece_count++;
      break;
    case 10:
      white_material += king;
      white_piece_count++;
      white_mean[0] += (i%8);
      white_mean[1] += (i/8);
      break;
    case -1:
      black_material += (pawn+(7-i/8)*(king-pawn)/14);
      black_piece_count++;
      black_mean[0] += (i%8);
      black_mean[1] += (i/8);
      break;
    case -10:

      black_material += king;
      black_piece_count++;
      black_mean[0] += (i%8);
      black_mean[1] += (i/8);
      break;
    }
  }
  white_mean[0] /= white_piece_count;
  white_mean[1] /= white_piece_count;
  black_mean[0] /= black_piece_count;
  black_mean[1] /= black_piece_count;
  if (white_material-black_material > 10) { //black is down on pieces
    trap_bonus -= 2*(abs(white_mean[0]-black_mean[0])+abs(white_mean[1]-black_mean[1])); //minimize the distance between white and black's pieces
    int d1 = abs(black_mean[0])+abs(black_mean[1]);
    int d2 = abs(7-black_mean[0])+abs(black_mean[1]);
    int d3 = abs(7-black_mean[0])+abs(7-black_mean[1]);
    int d4 = abs(black_mean[0])+abs(7-black_mean[1]);
    d1 = min(d1, d2, d3);
    trap_bonus += 5*min(d1, d4);//maximize the distance between black's pieces and the corners
  }
  if (black_material-white_material > 10) {
    trap_bonus += 2*(abs(white_mean[0]-black_mean[0])+abs(white_mean[1]-black_mean[1])); //minimize the distance between white and black's pieces 
    int d1 = abs(white_mean[0])+abs(white_mean[1]);
    int d2 = abs(7-white_mean[0])+abs(white_mean[1]);
    int d3 = abs(7-white_mean[0])+abs(7-white_mean[1]);
    int d4 = abs(white_mean[0])+abs(7-white_mean[1]);
    d1 = min(d1, d2, d3);
    trap_bonus -= 5*min(d1, d4);
    ;//maximize the distance between white's pieces and the corners
  }
  return ((1000*white_material)/black_material+trap_bonus*15) > 0 ? (1000*white_material)/black_material+trap_bonus*15 : (1000*white_material)/black_material;
}

/*
 Features yet to add:
 - Transposition tables
 - When the AI performs a multi-capture move, it lists them weird.
 - Improve the heuristic
 */


/*
   further optimizations:
 
 */