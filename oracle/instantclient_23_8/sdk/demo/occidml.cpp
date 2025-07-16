/* Copyright (c) 2001, 2023, Oracle and/or its affiliates.*/
/* All rights reserved. */
/*
   NAME
     occidml.cpp - Basic DML Operations demo

   DESCRIPTION
     To exhibit the insertion, selection, updating and deletion of
     a row using OCCI interface

   NOTE
     The program prompts to enter Username, Password and Database values.
*/
#include <sys/types.h>
#include <fstream>
#include <iostream>
#include <occi.h>
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

class  occidml
{
  private:

  Environment *env;
  Connection *conn;
  Statement *stmt;
  public:

  occidml (string user, string passwd, string db)
  {
    env = Environment::createEnvironment (Environment::DEFAULT);
    conn = env->createConnection (user, passwd, db);
  }

  ~occidml ()
  {
    env->terminateConnection (conn);
    Environment::terminateEnvironment (env);
  }

  /**
   * Insertion of a row with dynamic binding, PreparedStatement functionality.
   */
  void insertBind (int c1, string c2)
  {
    string sqlStmt = "INSERT INTO author_tab VALUES (:x, :y)";
    stmt=conn->createStatement (sqlStmt);
    try{
    stmt->setInt (1, c1);
    stmt->setString (2, c2);
    stmt->executeUpdate ();
    cout << "insert - Success" << endl;
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for insertBind"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    conn->terminateStatement (stmt);
  }

  /**
   * Inserting a row into the table.
   */
  void insertRow ()
  {
    string sqlStmt = "INSERT INTO author_tab VALUES (111, 'ASHOK')";
    stmt = conn->createStatement (sqlStmt);
    try{
    stmt->executeUpdate ();
    cout << "insert - Success" << endl;
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for insertRow"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    conn->terminateStatement (stmt);
  }

  /**
   * updating a row
   */
  void updateRow (int c1, string c2)
  {
    string sqlStmt = 
      "UPDATE author_tab SET author_name = :x WHERE author_id = :y";
    stmt = conn->createStatement (sqlStmt);
    try{
    stmt->setString (1, c2);
    stmt->setInt (2, c1);
    stmt->executeUpdate ();
    cout << "update - Success" << endl;
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for updateRow"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    conn->terminateStatement (stmt);
  }


  /**
   * deletion of a row
   */
  void deleteRow (int c1, string c2)
  {
    string sqlStmt = 
      "DELETE FROM author_tab WHERE author_id= :x AND author_name = :y";
    stmt = conn->createStatement (sqlStmt);
    try{
    stmt->setInt (1, c1);
    stmt->setString (2, c2);
    stmt->executeUpdate ();
    cout << "delete - Success" << endl;
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for deleteRow"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    conn->terminateStatement (stmt);
  }

  /**
   * displaying all the rows in the table
   */
  void displayAllRows ()
  {
    string sqlStmt = "SELECT author_id, author_name FROM author_tab \
    order by author_id";
    stmt = conn->createStatement (sqlStmt);
    ResultSet *rset = stmt->executeQuery ();
    try{
    while (rset->next ())
    {
      cout << "author_id: " << rset->getInt (1) << "  author_name: " 
        << rset->getString (2) << endl;
    }
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for displayAllRows"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    stmt->closeResultSet (rset);
    conn->terminateStatement (stmt);
  }

  /**
   * Inserting a row into elements table.
   * Demonstrating the usage of BFloat and BDouble datatypes
   */
  void insertElement (string elm_name, float mvol=0.0, double awt=0.0)
  {
    BFloat mol_vol;
    BDouble at_wt;

    if (!(mvol))
      mol_vol.isNull = TRUE;
    else
      mol_vol.value = mvol;

    if (!(awt))
      at_wt.isNull = TRUE;
    else
      at_wt.value = awt;

    string sqlStmt = "INSERT INTO elements VALUES (:v1, :v2, :v3)";
    stmt = conn->createStatement (sqlStmt);

    try{
    stmt->setString(1, elm_name);
    stmt->setBFloat(2, mol_vol);
    stmt->setBDouble(3, at_wt);
    stmt->executeUpdate ();
    cout << "insertElement - Success" << endl;
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for insertElement"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }
    conn->terminateStatement (stmt);
  }

  /**
   * displaying rows from element table
   */
  void displayElements ()
  {
    string sqlStmt = 
           "SELECT element_name, molar_volume, atomic_weight FROM elements \
    order by element_name";
    stmt = conn->createStatement (sqlStmt);
    ResultSet *rset = stmt->executeQuery ();
    try{
    cout.precision(7);
    while (rset->next ())
    {
      string elem_name = rset->getString(1);
      BFloat mol_vol = rset->getBFloat(2);
      BDouble at_wt = rset->getBDouble(3);

      cout << "Element Name: " << elem_name << endl;

      if ( mol_vol.isNull )
        cout << "Molar Volume is NULL" << endl;
      else
        cout << "Molar Volume: " << mol_vol.value << " cm3 mol-1" << endl;

      if ( at_wt.isNull )
        cout << "Atomic Weight is NULL" << endl;
      else
        cout << "Atomic Weight: " << at_wt.value << " g/mole" << endl;
    }
    }catch(SQLException ex)
    {
     cout<<"Exception thrown for displayElements"<<endl;
     cout<<"Error number: "<<  ex.getErrorCode() << endl;
     cout<<ex.getMessage() << endl;
    }

    stmt->closeResultSet (rset);
    conn->terminateStatement (stmt);
  }

}; // end of class  occidml


int main (void)
{
  getCredentials();
  try{
  cout << "occidml - Exhibiting simple insert, delete & update operations" 
       << endl;
  occidml *demo = new occidml (username, password, dbname);
  cout << "Displaying all records before any operation" << endl;
  demo->displayAllRows ();

  cout << "Inserting a record into the table author_tab " 
    << endl;
  demo->insertRow ();

  cout << "Displaying the records after insert " << endl;
  demo->displayAllRows ();

  cout << "Inserting a records into the table author_tab using dynamic bind"
    << endl;
  demo->insertBind (222, "ANAND");
 
  cout << "Displaying the records after insert using dynamic bind" << endl;
  demo->displayAllRows ();

  cout << "deleting a row with author_id as 222 from author_tab table" << endl;
  demo->deleteRow (222, "ANAND");

  cout << "updating a row with author_id as 444 from author_tab table" << endl;
  demo->updateRow (444, "ADAM");

  cout << "displaying all rows after all the operations" << endl;
  demo->displayAllRows ();

  cout << "inserting radio active element properties" << endl;
  demo->insertElement ("Uranium", 12.572, 238.0289 );
  demo->insertElement ("Plutonium", 12.12, 244.0642 );
  demo->insertElement ("Curium", 18.17, 247.0703 );
  demo->insertElement ("Thorium");
  demo->insertElement ("Radium", 41.337, 226.0254);

  cout << "displaying all radio active element properties" << endl;
  demo->displayElements ();

  delete (demo);
  }
  catch (SQLException ex){
    cout << ex.getMessage() << endl;
  }
  cout << "occidml - done" << endl;
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

