//+------------------------------------------------------------------+
//|                                                     DKLogger.mqh |
//|                                                  Denis Kislitsyn |
//|                                               http:/kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "http:/kislitsyn.me"
#property version   "0.0.1"


enum LogLevel {
  DEBUG=10,
  INFO=20,
  WARN=30,
  ERROR=40,
  CRITICAL=50,
};
   
class DKLogger {
  public:
    string   Name;
    LogLevel Level;
    string   Format;  // Avaliable patterns: %YYYY%, %MM%, %DD%, %hh%, %mm%, %ss%, %name%, %level%, %message%

    DKLogger(void) {Level = LogLevel(INFO);};
    DKLogger(string LoggerName, LogLevel MessageLevel = LogLevel(INFO)) {
      Name = LoggerName;
      Level = LogLevel(INFO);
    }
    
    void Log(string MessageTest, LogLevel MessageLevel = LogLevel(INFO)) {
      if (MessageLevel >= Level) 
        if (Format != "") {         
          string message = Format;
          datetime dt_local = TimeLocal();
          string date = TimeToString(dt_local, TIME_DATE);
          string sec = TimeToString(dt_local, TIME_SECONDS);
          
          
          StringReplace(message, "%YYYY%", StringSubstr(date, 0, 4));
          StringReplace(message, "%MM%", StringSubstr(date, 5, 2));
          StringReplace(message, "%DD%", StringSubstr(date, 8, 2));
          
          StringReplace(message, "%hh%", StringSubstr(sec, 0, 2));
          StringReplace(message, "%mm%", StringSubstr(sec, 3, 2));
          StringReplace(message, "%ss%", StringSubstr(sec, 6, 2));
          
          StringReplace(message, "%level%", EnumToString(MessageLevel));
          StringReplace(message, "%name%", Name);
          StringReplace(message, "%message%", MessageTest);
          
          Print(message);
        }
        else
          Print("[", TimeLocal(), "]:", Name, ":[", EnumToString(MessageLevel), "] ", MessageTest); 
    }; 
  
    void Debug(string MessageTest) {
      Log(MessageTest, LogLevel(DEBUG));
    };           

    void Info(string MessageTest) {
      Log(MessageTest, LogLevel(INFO));
    }; 
    
    void Warn(string MessageTest) {
      Log(MessageTest, LogLevel(WARN));
    };         
    
    void Error(string MessageTest) {
      Log(MessageTest, LogLevel(ERROR));
    };         
    
    void Critical(string MessageTest) { 
      Log(MessageTest, LogLevel(CRITICAL));
    };  
    
    void Assert(const bool aCondition, 
                const string aTrueMessage, const LogLevel aTrueLevel = INFO, 
                const string aFalseMessage = "", const LogLevel aFalseLevel = ERROR) {
      if (!aCondition) {
        if (aFalseMessage != "")
          Log(aFalseMessage, aFalseLevel);
      }
      else 
        Log(aTrueMessage, aTrueLevel);
    }               
};