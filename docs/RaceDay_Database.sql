/* ============================================================
   RaceDay Event Management System
   SQL Server Database Script
   PROG6212 - PoE Part 1
   Author: Caleb Walsh
   ============================================================
   This script creates the full RaceDay schema and seeds it with
   realistic sample data. Run the entire script top to bottom on
   a clean database. Safe to re-run: existing objects are dropped
   first.
   ============================================================ */

IF DB_ID('RaceDayDB') IS NULL
BEGIN
    CREATE DATABASE RaceDayDB;
END
GO

USE RaceDayDB;
GO

/* ------------------------------------------------------------
   Drop tables if they already exist (in FK-safe order)
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.Result', 'U') IS NOT NULL DROP TABLE dbo.Result;
IF OBJECT_ID('dbo.Enrolment', 'U') IS NOT NULL DROP TABLE dbo.Enrolment;
IF OBJECT_ID('dbo.Category', 'U') IS NOT NULL DROP TABLE dbo.Category;
IF OBJECT_ID('dbo.Event', 'U') IS NOT NULL DROP TABLE dbo.Event;
IF OBJECT_ID('dbo.[User]', 'U') IS NOT NULL DROP TABLE dbo.[User];
IF OBJECT_ID('dbo.Club', 'U') IS NOT NULL DROP TABLE dbo.Club;
GO

/* ------------------------------------------------------------
   Table: Club
   A running/cycling club a Participant may optionally belong to.
   ------------------------------------------------------------ */
CREATE TABLE dbo.Club (
    ClubID          INT IDENTITY(1,1)   PRIMARY KEY,
    ClubName        NVARCHAR(100)       NOT NULL UNIQUE,
    Province        NVARCHAR(50)        NOT NULL,
    DateEstablished DATE                NULL
);
GO

/* ------------------------------------------------------------
   Table: User
   Single table for both Organisers and Participants, distinguished
   by the Role column. Enforced further at the API level in Part 2.
   ------------------------------------------------------------ */
CREATE TABLE dbo.[User] (
    UserID          INT IDENTITY(1,1)   PRIMARY KEY,
    FullName        NVARCHAR(100)       NOT NULL,
    Email           NVARCHAR(150)       NOT NULL UNIQUE,
    PasswordHash    NVARCHAR(256)       NOT NULL,
    Role            NVARCHAR(20)        NOT NULL
                        CONSTRAINT CK_User_Role CHECK (Role IN ('Organiser','Participant')),
    PhoneNumber     NVARCHAR(20)        NULL,
    ClubID          INT                 NULL,
    DateRegistered  DATETIME            NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_User_Club FOREIGN KEY (ClubID) REFERENCES dbo.Club(ClubID)
);
GO

/* ------------------------------------------------------------
   Table: Event
   Created and managed by a User with Role = 'Organiser'.
   ------------------------------------------------------------ */
CREATE TABLE dbo.Event (
    EventID         INT IDENTITY(1,1)   PRIMARY KEY,
    EventName       NVARCHAR(150)       NOT NULL,
    Description     NVARCHAR(MAX)       NULL,
    EventDate       DATE                NOT NULL,
    Location        NVARCHAR(150)       NOT NULL,
    Distance        DECIMAL(6,2)        NOT NULL,
    EventType       NVARCHAR(30)        NOT NULL
                        CONSTRAINT CK_Event_Type CHECK (EventType IN ('Running','Walking','Cycling')),
    OrganiserID     INT                 NOT NULL,
    DateCreated     DATETIME            NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Event_Organiser FOREIGN KEY (OrganiserID) REFERENCES dbo.[User](UserID)
);
GO

/* ------------------------------------------------------------
   Table: Category
   Each Event has one or more Categories (e.g. 10km, 21km).
   ------------------------------------------------------------ */
CREATE TABLE dbo.Category (
    CategoryID      INT IDENTITY(1,1)   PRIMARY KEY,
    EventID         INT                 NOT NULL,
    CategoryName    NVARCHAR(50)        NOT NULL,
    MinAge          INT                 NULL,
    MaxParticipants INT                 NULL,
    EntryFee        DECIMAL(8,2)        NOT NULL DEFAULT 0,
    CONSTRAINT FK_Category_Event FOREIGN KEY (EventID) REFERENCES dbo.Event(EventID),
    CONSTRAINT UQ_Category_Event_Name UNIQUE (EventID, CategoryName)
);
GO

/* ------------------------------------------------------------
   Table: Enrolment
   Associative entity resolving the many-to-many between
   Participant and Event; also records the chosen Category.
   ------------------------------------------------------------ */
CREATE TABLE dbo.Enrolment (
    EnrolmentID     INT IDENTITY(1,1)   PRIMARY KEY,
    ParticipantID   INT                 NOT NULL,
    EventID         INT                 NOT NULL,
    CategoryID      INT                 NOT NULL,
    EnrolmentDate   DATETIME            NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Enrolment_User FOREIGN KEY (ParticipantID) REFERENCES dbo.[User](UserID),
    CONSTRAINT FK_Enrolment_Event FOREIGN KEY (EventID) REFERENCES dbo.Event(EventID),
    CONSTRAINT FK_Enrolment_Category FOREIGN KEY (CategoryID) REFERENCES dbo.Category(CategoryID),
    CONSTRAINT UQ_Enrolment_Participant_Event UNIQUE (ParticipantID, EventID)
);
GO

/* ------------------------------------------------------------
   Table: Result
   One Result per Enrolment, captured by the Organiser once the
   Participant has finished.
   ------------------------------------------------------------ */
CREATE TABLE dbo.Result (
    ResultID        INT IDENTITY(1,1)   PRIMARY KEY,
    EnrolmentID     INT                 NOT NULL UNIQUE,
    FinishTime      TIME                NULL,
    Position        INT                 NULL,
    CapturedDate    DATETIME            NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Result_Enrolment FOREIGN KEY (EnrolmentID) REFERENCES dbo.Enrolment(EnrolmentID)
);
GO

/* ================================================================
   SEED DATA
   ================================================================ */

-- Clubs
INSERT INTO dbo.Club (ClubName, Province, DateEstablished) VALUES
('Bellville Athletics Club', 'Western Cape', '1985-03-01'),
('Johannesburg Road Runners', 'Gauteng', '1976-06-15');

-- Users: 2 Organisers, 2 Participants
INSERT INTO dbo.[User] (FullName, Email, PasswordHash, Role, PhoneNumber, ClubID) VALUES
('Thandiwe Mokoena', 'thandiwe.mokoena@raceday.co.za', 'HASHED_PW_1', 'Organiser', '0821234567', NULL),
('Pieter van der Merwe', 'pieter.vdm@raceday.co.za', 'HASHED_PW_2', 'Organiser', '0837654321', NULL),
('Caleb Walsh', 'caleb.walsh@raceday.co.za', 'HASHED_PW_3', 'Participant', '0721112222', 1),
('Naledi Dlamini', 'naledi.dlamini@raceday.co.za', 'HASHED_PW_4', 'Participant', '0793334444', 2);

-- Events: 3 events, each created by an Organiser
INSERT INTO dbo.Event (EventName, Description, EventDate, Location, Distance, EventType, OrganiserID) VALUES
('Cape Town Peninsula Marathon', 'Scenic coastal marathon along the Cape Peninsula.', '2026-11-08', 'Cape Town, Western Cape', 42.20, 'Running', 1),
('Soweto Charity Cycle Tour', 'Community cycling event supporting local schools.', '2026-10-04', 'Soweto, Gauteng', 94.70, 'Cycling', 2),
('Kuils River Fun Walk', 'Family-friendly walking event for all ages.', '2026-09-27', 'Kuils River, Western Cape', 5.00, 'Walking', 1);

-- Categories for each Event
INSERT INTO dbo.Category (EventID, CategoryName, MinAge, MaxParticipants, EntryFee) VALUES
(1, 'Full Marathon (42.2km)', 18, 2000, 350.00),
(1, 'Half Marathon (21.1km)', 16, 3000, 250.00),
(2, 'Seeded Cyclists', 18, 500, 400.00),
(2, 'Unseeded Cyclists', 16, 1500, 300.00),
(3, 'Adults 5km', 12, 1000, 80.00),
(3, 'Under-12 Fun Walk', 0, 500, 0.00);

-- Sample Enrolments
INSERT INTO dbo.Enrolment (ParticipantID, EventID, CategoryID) VALUES
(3, 1, 2),  -- Caleb enters the Half Marathon
(4, 2, 3),  -- Naledi enters Seeded Cyclists
(3, 3, 5);  -- Caleb enters the 5km fun walk

-- Sample Results (only for enrolments that have "finished")
INSERT INTO dbo.Result (EnrolmentID, FinishTime, Position) VALUES
(1, '01:48:32', 214),
(2, '02:31:07', 58);

GO

/* ================================================================
   VERIFICATION QUERIES (optional - run after the script to check)
   ================================================================ */
-- SELECT * FROM dbo.Club;
-- SELECT * FROM dbo.[User];
-- SELECT * FROM dbo.Event;
-- SELECT * FROM dbo.Category;
-- SELECT * FROM dbo.Enrolment;
-- SELECT * FROM dbo.Result;
