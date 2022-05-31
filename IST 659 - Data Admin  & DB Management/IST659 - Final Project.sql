-- Amanda Austin: Final Project for IST659
--Vendor Database for Broadridge Financial Solutions

-- Dropping all tables, if they exist, to avoid errors from duplicate table names
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Movelog')
BEGIN
	DROP TABLE Movelog
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Job')
BEGIN
	DROP TABLE Job
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Client')
BEGIN
	DROP TABLE Client
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Employee')
BEGIN
	DROP TABLE Employee
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ConsolidatedSkid')
BEGIN
	DROP TABLE ConsolidatedSkid
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Load')
BEGIN
	DROP TABLE Load
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'VendorRep')
BEGIN
	DROP TABLE VendorRep
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Vendor')
BEGIN
	DROP TABLE Vendor
END
GO


-- Creating the tables from the logical model (excluding billing)
CREATE TABLE Client (
	ClientName varchar(50) not null,
	ClientRepFirstName varchar(30) not null,
	ClientRepLastName varchar(30) not null,
	ClientRepEmail varchar(50) not null,
	ClientRepPhoneNum varchar(15) not null,
	ClientID int identity,
	CONSTRAINT PK_Client PRIMARY KEY (ClientID),
	CONSTRAINT U1_Client UNIQUE (ClientRepEmail),
	CONSTRAINT U2_Client UNIQUE (ClientRepPhoneNum))

CREATE TABLE Job (
	JobNumber char(10) not null,
	ClientID int not null,
	JobID int identity,
	CONSTRAINT PK_Job PRIMARY KEY (JobID),
	CONSTRAINT U1_Job UNIQUE (JobNumber),
	CONSTRAINT FK_Job FOREIGN KEY (ClientID) REFERENCES Client(ClientID))

CREATE TABLE Employee (
	EmployeeFirstName varchar(30) not null,
	EmployeeLastName varchar(30) not null,
	EmployeeShift varchar(5) not null,
	EmployeeID int identity,
	CONSTRAINT PK_Employee PRIMARY KEY (EmployeeID))

CREATE TABLE Vendor (
	VendorName varchar(50) not null,
	VendorID int identity,
	CONSTRAINT PK_Vendor PRIMARY KEY (VendorID))

CREATE TABLE VendorRep (
	VendorRepFirstName varchar(30) not null,
	VendorRepLastName varchar(30) not null,
	VendorRepEmail varchar(30) not null,
	VendorRepPhoneNum varchar(15) not null,
	VendorID int not null,
	VendorRepID int identity,
	CONSTRAINT PK_VendorRep PRIMARY KEY (VendorRepID),
	CONSTRAINT U1_VendorRep UNIQUE (VendorRepEmail),
	CONSTRAINT U2_VendorRep UNIQUE (VendorRepPhoneNum),
	CONSTRAINT FK1_VendorRep FOREIGN KEY (VendorID) REFERENCES Vendor(VendorID))

CREATE TABLE Load (
	TruckTrailerNum char(5) not null,
	LoadDateTime datetime not null DEFAULT GETDATE(),
	VendorID int,
	LoadID int identity,
	CONSTRAINT PK_Load PRIMARY KEY (LoadID),
	CONSTRAINT FK1_Load FOREIGN KEY (VendorID) REFERENCES Vendor(VendorID))

CREATE TABLE ConsolidatedSkid (
	ConSkidDateTime datetime not null DEFAULT GETDATE(),
	LoadID int,
	ConSkidID int identity,
	CONSTRAINT PK_ConsolidatedSkid PRIMARY KEY (ConSkidID),
	CONSTRAINT FK1_ConsolidatedSkid FOREIGN KEY (LoadID) REFERENCES Load(LoadID))

CREATE TABLE Movelog (
	MailClass varchar(20) not null,
	OutboundPieceWeight decimal(3,1) not null,
	OutboundPieces int not null,
	MLBarcode varchar(50) not null,
	ScanDateTime datetime not null DEFAULT GETDATE(),
	ConSkidID int,
	JobID int not null,
	EmployeeID int not null,
	MovelogID int identity,
	CONSTRAINT PK_Movelog PRIMARY KEY (MovelogID),
	CONSTRAINT U1_Movelog Unique (MLBarcode),
	CONSTRAINT FK1_Movelog FOREIGN KEY (ConSkidID) REFERENCES ConsolidatedSkid(ConSkidID),
	CONSTRAINT FK2_Movelog Foreign Key (JobID) REFERENCES Job(JobID),
	CONSTRAINT FK3_Movelog FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID))

-- Ensure all data was imported into SQL through Access
SELECT * FROM Movelog
SELECT * FROM Job
SELECT * FROM Client
SELECT * FROM Employee
SELECT * FROM ConsolidatedSkid
SELECT * FROM Load
SELECT * FROM Vendor
SELECT * FROM VendorRep

-- Inserting new job number for testing purposes
-- Once go live, jobs will be entered into the database through Access
INSERT INTO Job (JobNumber, ClientID) VALUES ('S12345-010', 1)
GO

-- Verifying the movelog for test job S12345 was scanned into the vendor DB
SELECT
	MLBarcode,
	MailClass,
	OutboundPieceWeight AS Weight,
	OutboundPieces AS Pieces,
	JobNumber,
	CONCAT (EmployeeLastName,', ',EmployeeFirstName) AS EmployeeName,
	ScanDateTime,
	ClientName
	FROM Employee
	JOIN Movelog ON Employee.EmployeeID = Movelog.EmployeeID
	JOIN Job ON Movelog.JobID = Job.JobID
	JOIN Client ON Job.CLientID = Client.ClientID
	WHERE MLBarcode = 'S12345-010A0000401234  0.200'
GO

-- SQL for Scan a Movelog Form
CREATE PROCEDURE ScanML (@MLBarcode varchar(50), @MailClass varchar(20), @PcWeight decimal (3,1), @Pcs int, @JobNumber char(10), @EmployeeLastName varchar(30)) AS
	BEGIN
	INSERT INTO Movelog (MLBarcode, MailClass, OutboundPieceWeight, OutboundPieces, JobID, EmployeeID)
		VALUES (@MLBarcode, @MailClass, @PcWeight, @Pcs,
		(SELECT JobID FROM Job WHERE JobNumber = @JobNumber),
		(SELECT EmployeeID FROM Employee WHERE EmployeeLastName = @EmployeeLastName))
	END
GO

-- Assigning the movelog to a consolidated skid
CREATE PROCEDURE CreateConSkid (@MLBarcode varchar(50)) AS
	BEGIN
	INSERT INTO ConsolidatedSkid (ConSkidDateTime) VALUES ('')
	UPDATE Movelog SET ConSkidID = @@IDENTITY WHERE MovelogID = (SELECT MovelogID FROM Movelog WHERE MLBarcode = @MLBarcode)
	END
	GO

-- Assigning the consolidated skid to a load and vendor
CREATE PROCEDURE CreateLoad (@MLBarcode varchar(50), @TTNum char(5), @Vendor varchar(50)) AS
	BEGIN
	INSERT INTO Load (TruckTrailerNum, VendorID) VALUES (@TTNum, (SELECT VendorID FROM Vendor WHERE VendorName = @Vendor))
	UPDATE ConsolidatedSkid SET LoadID = @@IDENTITY WHERE ConSkidID = (SELECT ConSkidID FROM Movelog WHERE MLBarcode = @MLBarcode)
	END
	GO

-- Adding a second movelog from test job S12345 to the database
EXEC ScanML 'S12345-010S0000300500  0.200', 'FC', '0.2', '500', 'S12345-010', 'Forbes'
EXEC CreateConSkid 'S12345-010S0000300500  0.200'
EXEC CreateLoad 'S12345-010S0000300500  0.200', 42005, 'BRCC'

-- Dropping the view, if it exists, to avoid errors from duplicate names
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AverageProcessingTime')
BEGIN
	DROP VIEW AverageProcessingTime
END
GO

-- Create view to calculte Average Processing Time
CREATE VIEW AverageProcessingTime AS
SELECT
	AVG(DATEDIFF(hh, LoadDateTime, ScanDateTime)) AS AvgProcessingTime
	FROM Load
	JOIN ConsolidatedSkid ON Load.LoadID = ConsolidatedSkid.LoadID
	JOIN Movelog ON ConsolidatedSkid.ConSkidID = Movelog.ConSkidID
GO

-- Return view average processing time
SELECT * FROM AverageProcessingTime


