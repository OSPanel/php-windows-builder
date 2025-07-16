/* Copyright (c) 2001, 2023, Oracle and/or its affiliates.*/
/* All rights reserved. */
/*
   NAME
     occiobj.cpp - OCCI Embedded Object demo

   DESCRIPTION
     This demo performs all DML operations using OCCI interface
     on embedded object column of table

   NOTE
     The program prompts to enter Username, Password and Database values.
*/
#include <sys/types.h>
#include <fstream>
#include <iostream>
#include "occiobjm.h"
#include <cstdlib>
#include <string.h>

using namespace oracle::occi;
using namespace std;

#define USERNAME_LEN 256
#define PASSWORD_LEN 1025
#define DBNAME_LEN   1025

#if defined(WIN32COMMON) || defined(WIN32) || defined(_WIN32)
int getline(char **bufp, size_t *bufl, FILE *stream);
int getline(char **bufp, size_t *bufl, FILE *stream)
{
  fgets(*bufp, *bufl, stream);
  if (ferror(stream))
    return -1;
  return strlen(*bufp);
}
#endif

static  char *username;
static  char *password;
static  char *dbname;

static int getCredentials();

class occiobj
{
  private:

  Environment *env;
  Connection *con;
  Statement *stmt;
  public:

  occiobj (string user, string passwd, string db)
  {
    env = Environment::createEnvironment (Environment::OBJECT);
    occiobjm (env);
    con = env->createConnection (user, passwd, db);
  }

  ~occiobj ()
  {
    env->terminateConnection (con);
    Environment::terminateEnvironment (env);
  }

  /**
   * Insertion of a row 
   */
  void insertRow (int c1, int a1, string a2)
  {
    cout << "Inserting record - Publisher id :" << c1 << 
      ", Publisher address :" << a1 << ", " << a2 <<endl; 
    string sqlStmt = "INSERT INTO publisher_tab VALUES (:x, :y)";
    try{
    stmt = con->createStatement (sqlStmt);
    stmt->setInt (1, c1);
    address *o = new address ();
    o->setStreet_no (Number (a1));
    o->setCity (a2);
    stmt->setObject (2, o);
    stmt->executeUpdate ();
    cout << "Insert - Success" << endl;
    delete (o);
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for insertRow"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    con->terminateStatement (stmt);
  }


  /**
   * updating a row
   */
  void updateRow (int c1, int a1, string a2)
  {
    cout << "Upadating record with publisher id :"<< c1 << endl;
    string sqlStmt = 
      "UPDATE publisher_tab SET publisher_add= :x WHERE publisher_id = :y";
    try{
    stmt = con->createStatement (sqlStmt);
    address *o = new address ();
    o->setStreet_no (Number (a1));
    o->setCity (a2);
    stmt->setObject (1, o);
    stmt->setInt (2, c1);
    stmt->executeUpdate ();
    cout << "Update - Success" << endl;
    delete (o);
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for updateRow"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }
    con->terminateStatement (stmt);
  }


  /**
   * deletion of a row
   */
  void deleteRow (int c1, int a1, string a2)
  {
    cout << "Deletion of record where publisher id :" << c1 <<endl; 
    string sqlStmt = 
    "DELETE FROM publisher_tab WHERE publisher_id= :x AND publisher_add = :y";
    try{
    stmt = con->createStatement (sqlStmt);
    stmt->setInt (1, c1);

    address *o = new address ();
    o->setStreet_no (Number (a1));
    o->setCity (a2);
    stmt->setObject (2, o);
    stmt->executeUpdate ();
    cout << "Delete - Success" << endl;
    delete (o);
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for deleteRow"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    con->terminateStatement (stmt);
  }

  /**
   * displaying all the rows in the table
   */
  void displayAllRows ()
  {
    string sqlStmt = "SELECT publisher_id, publisher_add FROM publisher_tab \
    order by publisher_id";
    try{
    stmt = con->createStatement (sqlStmt);
    ResultSet *rset = stmt->executeQuery ();
   
    while (rset->next ())
    {
      cout << "publisher id: " << rset->getInt (1) 
           << " publisher address: address (" ;
      address *o =  (address *)rset->getObject (2);
      cout << (int)o->getStreet_no () << ", " << o->getCity () << ")" << endl;
    }

    stmt->closeResultSet (rset);
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for displayAllRows"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    con->terminateStatement (stmt);
  }

};//end of class occiobj;


int main (void)
{
  getCredentials();
  try
  {
    cout << "occiobj - Exhibiting simple insert, delete & update operations" 
     " on Oracle objects" << endl;
    occiobj *demo = new occiobj (username, password, dbname);

    cout << "displaying all rows before operations" << endl;
    demo->displayAllRows ();
  
    demo->insertRow (12, 122, "MIKE");
  
    demo->deleteRow (11, 121, "ANNA");
  
    demo->updateRow (23, 123, "KNUTH");
  
    cout << "displaying all rows after all operations" << endl;
    demo->displayAllRows ();
  
    delete (demo);
    cout << "occiobj - done" << endl;
  }catch (SQLException ea)
  {
    cerr << "Error running the demo: " << ea.getMessage () << endl;
  }
}

static int getCredentials()
{
  size_t usernameLen = USERNAME_LEN;
  size_t passwordLen = PASSWORD_LEN;
  size_t dbnameLen = DBNAME_LEN;
  int nread;
  username = (char *) malloc(USERNAME_LEN * sizeof(char));
  password = (char *) malloc(PASSWORD_LEN * sizeof(char));
  dbname = (char *) malloc(DBNAME_LEN * sizeof(char));

  memset(username, 0, USERNAME_LEN);
  memset(password, 0, PASSWORD_LEN);
  memset(dbname, 0, DBNAME_LEN);

  cout << "enter username:";
  if ((nread = getline(&username, &usernameLen, stdin)) == -1)
  {
    cout << "ERROR: Failed to get username\n";
    return -1;
  }
  if(strlen(username) >= 1)
    username[strlen(username)-1] = '\0';
  cout << "enter password:";
  if ((nread = getline(&password, &passwordLen, stdin)) == -1)
  {
    cout << "ERROR: Failed to get password\n";
    return -1;
  }
  if(strlen(password) >= 1)
    password[strlen(password)-1] = '\0';
  cout << "enter dbname:";
  if ((nread = getline(&dbname, &dbnameLen, stdin)) == -1)
  {
    cout << "ERROR: Failed to get dbname\n";
    return -1;
  }
  if(strlen(dbname) >= 1)
    dbname[strlen(dbname)-1] = '\0';

  cout << "\n";
  
  return 0;
}

