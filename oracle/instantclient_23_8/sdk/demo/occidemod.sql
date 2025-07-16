/* Copyright (c) 2002, 2024, Oracle and/or its affiliates. */
/* All rights reserved.*/

/*
  NAME
    occidemod - SQL Script to drop OCCI demo objects

  DESCRIPTION
    SQL Script to drop OCCI demo objects created by occidemo.sql
    To be run in the end to drop OCCI demo objects from HR schema

*/

/* Assumption: logon using username/password has happened outside this file */

Rem
Rem BEGIN SQL_FILE_METADATA
Rem SQL_SOURCE_FILE: rdbms/demo/occidemod.sql
Rem SQL_SHIPPED_FILE: rdbms/demo/occidemod.sql
Rem SQL_PHASE: DBMSPIPE
Rem SQL_STARTUP_MODE: NORMAL
Rem SQL_IGNORABLE_ERRORS: NONE
Rem END SQL_FILE_METADATA
Rem

DROP PROCEDURE demo_proc;
DROP FUNCTION demo_fun;

DROP TABLE elements;
DROP TABLE author_tab;
DROP TABLE publisher_tab;
DROP TABLE publ_address_tab;
DROP TABLE journal_tab;
DROP TABLE article_tab;
DROP TABLE librarian_tab;
DROP TABLE book;
DROP TABLE cover;

DROP TYPE journal;
DROP TYPE publ_address;
DROP TYPE librarian;
DROP TYPE people_obj;


DROP TABLE electronic_media;
DROP TYPE elheader_typ;
DROP TYPE elecdoc_tab;
DROP TYPE elecdoc_typ;

DROP TABLE foreign_student_tab;
DROP TABLE parttime_stud_tab;
DROP TABLE student_tab;
DROP TABLE people_tab;
DROP TYPE foreign_student;
DROP TYPE parttime_stud;
DROP TYPE student;
DROP TYPE people_typ;

DROP TYPE scott_obj;

DROP TABLE weights_float64;
DROP TABLE weights_binary;

