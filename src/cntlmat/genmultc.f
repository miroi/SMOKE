
        SUBROUTINE GENMULTC( CDEV, GDEV, LDEV, MDEV, NCPE, PYEAR,
     &                       ENAME, MNAME, CFLAG, GFLAG, LFLAG, 
     &                       SFLAG, MFLAG )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine computes the multiplicative control factors
C      and writes out the multiplicative control matrix.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     
C
C***************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel gsions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2002, MCNC Environmental Modeling Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Modeling Center
C MCNC  
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C smoke@emc.mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C.........  MODULES for public variables
C.........  This module contains the inventory arrays
        USE MODSOURC, ONLY: CSOURC

C.........  This module contains the control packet data and control matrices
        USE MODCNTRL, ONLY: FACCEFF, FACREFF, FACRLPN,
     &                      BASCEFF, BASREFF, BASRLPN,
     &                      EMSCEFF, EMSREFF, EMSRLPN,
     &                      NVCMULT, PNAMMULT, FACTOR,
     &                      DATVAL, BACKOUT, GRPINDX, GRPFLAG,
     &                      GRPINEM, GRPOUTEM, RPTDEV, PCTLFLAG,
     &                      EMSTOTL, CUTCTG, FACCTG, FACMACT, 
     &                      FACRACT, EMCAPALW, EMREPALW, GRPSTIDX,
     &                      GRPCHAR, EMSPTCF, MACEXEFF, MACNWEFF,
     &                      MACNWFRC, CTLRPLC

C.........  This module contains the information about the source category
        USE MODINFO, ONLY: CATEGORY, NSRC, NEM, NDY, NCE, NRE, NRP, 
     &                     NPPOL, BYEAR, NCHARS, CATDESC, CRL

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  i/o api parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.
        INCLUDE 'SETDECL.EXT'   !  FileSetAPI variables and functions
        INCLUDE 'FLTERR.EXT'    !  functions for comparing two numbers

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2 CRLF
        LOGICAL     ENVYN
        INTEGER     GETEFILE
        INTEGER     INDEX1
        INTEGER     PROMPTFFILE
        REAL        YR2DAY

        EXTERNAL  CRLF, ENVYN, GETEFILE, INDEX1, PROMPTFFILE, YR2DAY

C...........   SUBROUTINE ARGUMENTS

        INTEGER     , INTENT (IN OUT) :: CDEV   ! file unit no. for tmp CTL file 
        INTEGER     , INTENT (IN OUT) :: GDEV   ! file unit no. for tmp CTG file
        INTEGER     , INTENT (IN OUT) :: LDEV   ! file unit no. for tmp ALW file
        INTEGER     , INTENT (IN OUT) :: MDEV   ! file unit no. for tmp MACT file
        INTEGER     , INTENT (IN) :: NCPE   ! no. of control packet entries
        INTEGER     , INTENT (IN) :: PYEAR  ! projected year, or missing
        CHARACTER*16, INTENT (IN) :: ENAME  ! logical name for i/o api 
                                            ! inventory input file
        CHARACTER*16, INTENT (IN OUT) :: MNAME  ! logical name for mult. cntl. mat.
        LOGICAL     , INTENT (IN) :: CFLAG  ! true = apply CTL controls
        LOGICAL     , INTENT (IN) :: GFLAG  ! true = apply CTG controls
        LOGICAL     , INTENT (IN) :: LFLAG  ! true = apply ALW controls
        LOGICAL     , INTENT (IN) :: SFLAG  ! true = apply EMS_CTL controls
        LOGICAL     , INTENT (IN) :: MFLAG  ! true = apply MACT controls

C...........   Local allocatable arrays
c        INTEGER, ALLOCATABLE :: ALWINDX ( :,: ) ! indices to ALW controls table
c        INTEGER, ALLOCATABLE :: CTGINDX ( :,: ) ! indices to CTG controls table
c        INTEGER, ALLOCATABLE :: CTLINDX ( :,: ) ! indices to CTL controls table
c        INTEGER, ALLOCATABLE :: GRPINDX ( : )   ! index from sources to groups
c        INTEGER, ALLOCATABLE :: GRPSTIDX( : )   ! sorting index

c        REAL   , ALLOCATABLE :: GRPINEM ( :,: ) ! initial emissions
c        REAL   , ALLOCATABLE :: GRPOUTEM( :,: ) ! controlled emissions

c        LOGICAL, ALLOCATABLE :: GRPFLAG ( : )   ! true: group controlled

c        CHARACTER(LEN=STALEN3+SCCLEN3), ALLOCATABLE :: GRPCHAR( : ) ! group chars
c        REAL   , ALLOCATABLE :: BACKOUT ( : )   ! factor used to account for pol
                                                ! specific control info that is
                                                ! already in the inventory
c        REAL   , ALLOCATABLE :: DATVAL  ( :,: ) ! emissions and control settings
c        REAL   , ALLOCATABLE :: FACTOR  ( : )   ! multiplicative controls

C.........   Local arrays
        INTEGER                 OUTTYPES( NVCMULT,6 ) ! var type:int/real
        INTEGER                 ODEV( 4 )             ! tmp output files
        CHARACTER(LEN=IOVLEN3)  OUTNAMES( NVCMULT,6 ) ! var names
        CHARACTER(LEN=IOULEN3)  OUTUNITS( NVCMULT,6 ) ! var units
        CHARACTER(LEN=IODLEN3)  OUTDESCS( NVCMULT,6 ) ! var descriptions

C...........   Other local variables
        INTEGER          E, I, J, K, L2, S  ! counters and indices

        INTEGER       :: ALWINDX = 0 ! indices to ALW controls table
        INTEGER       :: CTGINDX = 0 ! indices to CTG controls table
        INTEGER       :: CTLINDX = 0 ! indices to CTL controls table
        INTEGER       :: MACINDX = 0 ! indices to MACT controls table
        INTEGER          IDX      ! group index
        INTEGER          IOS      ! input/output status
        INTEGER          PIDX     ! previous IDX
        INTEGER          RDEV     ! Report unit number
        INTEGER          SCCBEG   ! begining of SCC in CSOURC string
        INTEGER          SCCEND   ! end of SCC in CSOURC string

        REAL             ALWEMIS  ! allowable emissions
        REAL             CAP      ! emissions cap
        REAL             CTGFAC   ! control technology control factor
        REAL             CTGFAC2  ! MAXACF or RSNACF
        REAL             CTLEFF   ! tmp control efficiency
        REAL             CUTOFF   ! CTG cutoff for application of control
        REAL             DENOM    ! denominator of control back-out factor
        REAL             E1, E2   ! tmp emissions values
        REAL             EXSTCEFF ! control efficiency for existing sources
        REAL             FAC      ! tmp control factor
        REAL             INVEFF   ! inventory baseline efficiency
        REAL             MACT     ! max. achievable cntrl tech. cntrl factor
        REAL             NEWCEFF  ! control efficiency for new sources
        REAL             NEWFRAC  ! fraction of new sources vs. existing
        REAL             RACT     ! reasonably achiev. cntrl tech. cntrl factor
        REAL             REPLACE  ! replacement emissions
        REAL             RULEFF   ! tmp rule effectiveness
        REAL             RULPEN   ! tmp rule penetration

        LOGICAL          LAVEDAY  ! true: use average day emissions
        LOGICAL, SAVE :: APPLFLAG = .FALSE. ! true: something has been applied
        LOGICAL, SAVE :: OPENFLAG = .FALSE. ! true: output file has been opened

        CHARACTER*100          OUTFMT     ! header format buffer
        CHARACTER*200          PATHNM     ! path name for tmp file
        CHARACTER*220          FILENM     ! file name
        CHARACTER*256          BUFFER     ! source fields buffer
        CHARACTER*256          MESG       ! message buffer
        CHARACTER(LEN=SRCLEN3) CSRC       ! tmp source chars
        CHARACTER(LEN=IOVLEN3) PNAM       ! tmp pollutant name
        CHARACTER(LEN=IOVLEN3) CBUF       ! pollutant name temporary buffer 
        CHARACTER(LEN=IOVLEN3) EBUF       ! pollutant name temporary buffer 

        CHARACTER*16  :: PROGNAME = 'GENMULTC' ! program name

C***********************************************************************
C   begin body of subroutine GENMULTC

C.........  Get environment variables that control program behavior
        MESG = 'Use annual or average day emissions'
        LAVEDAY = ENVYN( 'SMK_AVEDAY_YN', MESG, .FALSE., IOS )

C.........  Get path for temporary files
        MESG = 'Path where temporary control files will be written'
        CALL ENVSTR( 'SMK_TMPDIR', MESG, '.', PATHNM, IOS )

C.........  Open reports file
        RPTDEV( 1 ) = PROMPTFFILE( 
     &                'Enter logical name for MULTIPLICATIVE ' //
     &                'CONTROLS REPORT',
     &                .FALSE., .TRUE., CRL // 'CREP', PROGNAME )
        RDEV = RPTDEV( 1 )

C.........  Open *output* temporary files depending on whether an input 
C           temporary file exists - indicating that the packet is being used
        IF( CDEV .GT. 0 ) THEN
            FILENM = TRIM( PATHNM ) // '/cntlmat_tmp_ctl_rep'
            ODEV( 1 ) = GETEFILE( FILENM, .FALSE., .TRUE., PROGNAME )
        END IF
        IF( GDEV .GT. 0 ) THEN
            FILENM = TRIM( PATHNM ) // '/cntlmat_tmp_ctg_rep'
            ODEV( 2 ) = GETEFILE( FILENM, .FALSE., .TRUE., PROGNAME )
        END IF
        IF( LDEV .GT. 0 ) THEN
            FILENM = TRIM( PATHNM ) // '/cntlmat_tmp_alw_rep'
            ODEV( 3 ) = GETEFILE( FILENM, .FALSE., .TRUE., PROGNAME )
        ENDIF
        IF( MDEV .GT. 0 ) THEN
            FILENM = TRIM( PATHNM ) // '/cntlmat_tmp_mact_rep'
            ODEV( 4 ) = GETEFILE( FILENM, .FALSE., .TRUE., PROGNAME )
        END IF

C.........  Allocate index to reporting groups
c        ALLOCATE( GRPINDX( NSRC ), STAT=IOS )
c        CALL CHECKMEM( IOS, 'GRPINDX', PROGNAME )
c        ALLOCATE( GRPSTIDX( NSRC ), STAT=IOS )
c        CALL CHECKMEM( IOS, 'GRPSTIDX', PROGNAME )
c        ALLOCATE( GRPCHAR( NSRC ), STAT=IOS )
c        CALL CHECKMEM( IOS, 'GRPCHAR', PROGNAME )
c        GRPINDX  = 0  ! array

C.........  Get set up for group reporting...
c        IF( CATEGORY .EQ. 'POINT' ) THEN

C.............  Count the number of groups in the inventory
c           PPLT = ' '
c            NGRP = 0
c            DO S = 1, NSRC
c                CPLT = CSOURC( S )( 1:FPLLEN3 )
c                IF( CPLT .NE. PPLT ) THEN
c                    NGRP = NGRP + 1
c                    PPLT = CPLT
c                END IF
c                GRPINDX ( S ) = NGRP
c                GRPSTIDX( S ) = S     ! Needed for loops, but not used to sort
c            END DO

c        ELSE 

            IF( CATEGORY .EQ. 'AREA' ) THEN
                SCCBEG = ARBEGL3( 2 )
                SCCEND = ARENDL3( 2 )
            ELSE            ! MOBILE
                SCCBEG = MBBEGL3( 5 )
                SCCEND = MBENDL3( 5 )
            END IF

C.............  Build and sort source array for SCC-state grouping
c            DO S = 1, NSRC
c                CSTA = CSOURC( S )( 1     :STALEN3 )
c                TSCC = CSOURC( S )( SCCBEG:SCCEND  )

c                GRPSTIDX( S ) = S  
c                GRPCHAR ( S ) = CSTA // TSCC
c            END DO

c            CALL SORTIC( NSRC, GRPSTIDX, GRPCHAR )

C.............  Count the number of state/SCCs in the domain
c            PSTA = ' '
c            PSCC = ' '
c            SCCBEG = STALEN3 + 1
c            SCCEND = STALEN3 + SCCLEN3
c            DO S = 1, NSRC
c                J = GRPSTIDX( S )
c                CSTA = GRPCHAR( J )( 1     :STALEN3 )
c                TSCC = GRPCHAR( J )( SCCBEG:SCCEND  )
c                IF( CSTA .NE. PSTA .OR. TSCC .NE. PSCC ) THEN
c                    NGRP = NGRP + 1
c                    PSTA = CSTA
c                    PSCC = TSCC
c                END IF
c                GRPINDX( J ) = NGRP
c            END DO

c        END IF

C...........  Allocate memory for the number of groups for storing emissions
c          ALLOCATE( GRPFLAG( NGRP ), STAT=IOS )
c          CALL CHECKMEM( IOS, 'GRPFLAG', PROGNAME )
c          ALLOCATE( GRPINEM( NGRP, NVCMULT ), STAT=IOS )
c          CALL CHECKMEM( IOS, 'GRPINEM', PROGNAME )
c          ALLOCATE( GRPOUTEM( NGRP, NVCMULT ), STAT=IOS )
c          CALL CHECKMEM( IOS, 'GRPOUTEM', PROGNAME )

C...........  Initialize
c          GRPINEM  = 0. ! array
c          GRPOUTEM = 0. ! array
c          GRPFLAG  = .FALSE.  ! array

C...........  Allocate local memory
c          ALLOCATE( BACKOUT( NSRC ), STAT=IOS )
c          CALL CHECKMEM( IOS, 'BACKOUT', PROGNAME )
c          ALLOCATE( DATVAL( NSRC,NPPOL ), STAT=IOS )
c          CALL CHECKMEM( IOS, 'DATVAL', PROGNAME )
c          ALLOCATE( FACTOR( NSRC ), STAT=IOS )
c          CALL CHECKMEM( IOS, 'FACTOR', PROGNAME )

C...........  For each pollutant that receives controls, obtain variable
C             names for control efficiency, rule effectiveness, and, in the
C             case of AREA sources, rule penetration. These variable names
C             will be used in reading the inventory file.

        CALL BLDENAMS( CATEGORY, NVCMULT, 6, PNAMMULT, OUTNAMES,
     &                 OUTUNITS, OUTTYPES, OUTDESCS )

        DO I = 1, 6
            IF( OUTNAMES( 1,I )(1:IOVLEN3)  .EQ. PNAMMULT(1) ) NEM = I
            IF( OUTNAMES( 1,I )(1:CPRTLEN3) .EQ. AVEDAYRT ) NDY = I
            IF( OUTNAMES( 1,I )(1:CPRTLEN3) .EQ. CTLEFFRT ) NCE = I
            IF( OUTNAMES( 1,I )(1:CPRTLEN3) .EQ. RULEFFRT ) NRE = I
            IF( OUTNAMES( 1,I )(1:CPRTLEN3) .EQ. RULPENRT ) NRP = I
        END DO

C...........  Ensure the temporary files, if opened, are rewound
        IF( CDEV .GT. 0 ) REWIND( CDEV )
        IF( GDEV .GT. 0 ) REWIND( GDEV )
        IF( LDEV .GT. 0 ) REWIND( LDEV )
        IF( MDEV .GT. 0 ) REWIND( MDEV )

C...........  Fractionalize control-packet information

        IF( MFLAG ) THEN
            MACEXEFF = MACEXEFF*0.01  ! array
            MACNWEFF = MACNWEFF*0.01  ! array
            MACNWFRC = MACNWFRC*0.01  ! array
        END IF

        IF( CFLAG ) THEN
            FACCEFF = FACCEFF*0.01  ! array
            FACREFF = FACREFF*0.01  ! array
            FACRLPN = FACRLPN*0.01  ! array
        END IF

        IF( SFLAG ) THEN
            BASCEFF = BASCEFF*0.01  ! array
            BASREFF = BASREFF*0.01  ! array
            BASRLPN = BASRLPN*0.01  ! array
            EMSCEFF = EMSCEFF*0.01  ! array
            EMSREFF = EMSREFF*0.01  ! array
            EMSRLPN = EMSRLPN*0.01  ! array
        END IF

C...........  Set emissions index depending on average day or not
        E = NEM
        IF( LAVEDAY ) E = NDY

C...........  Loop through pollutants that receive controls
        DO I = 1, NVCMULT

C............  Set tmp pollutant name 
            PNAM = PNAMMULT( I )
            EBUF = OUTNAMES(I,1)          ! set annual emis name

C............  Initialize control factor array
            FACTOR = 1.0  ! array

C...........  Read in emissions data from inventory file...
C...........  From map-formatted inventory or old format
            CALL RDMAPPOL( NSRC, 1, NPPOL, EBUF, DATVAL )
            
C...........  Adjust emissions values and compute group values
            FAC = YR2DAY( BYEAR )  ! year to day factor for later
            DO S = 1, NSRC

C...............  Check for missing values and reset to zero
                IF( DATVAL( S,E ) .LT. AMISS3 ) DATVAL( S,E ) = 0.0

C...............  Divide annual emissions to get average day
                IF( .NOT. LAVEDAY ) DATVAL( S,E ) = DATVAL( S,E ) * FAC

C.................  Compute group emissions before controls
                J = GRPINDX( S )
                GRPINEM ( J,I ) = GRPINEM ( J,I ) + DATVAL( S,E )

            END DO ! end source loop

C...........  If CONTROL packet is present: For the current pollutant, read
C             in control efficiency, rule effectiveness, and, in the case of 
C             AREA sources, rule penetration.
            IF ( CFLAG ) THEN

C...........  Then calculate the factor which will be used to account 
C             for control information already in the inventory
                DO S = 1, NSRC

                    CTLEFF = 0.
                    RULEFF = 1.
                    RULPEN = 1.
                    IF ( NCE .GT. 0 ) CTLEFF = DATVAL( S,NCE )
                    IF ( NRE .GT. 0 ) RULEFF = DATVAL( S,NRE )
                    IF ( NRP .GT. 0 ) RULPEN = DATVAL( S,NRP )

C..................  Perform division by zero check.
                 
                    DENOM = ( 1.0 - CTLEFF*RULEFF*RULPEN )

                    IF ( FLTERR( DENOM, 0.0 ) ) THEN
                        BACKOUT( S ) = 1.0/DENOM
                    ELSE
                        BACKOUT( S ) = 0.0
                    END IF

                END DO ! end source loop

C...........  If EMS-95 CONTROL packet is present:
           ELSE IF ( SFLAG ) THEN

C..................  Perform division by zero check. 
              DO J = 1, NCPE

                 DENOM = ( 1.0 - BASCEFF(J)*BASREFF(J)*BASRLPN(J) )

                 IF ( FLTERR( DENOM, 0.0 ) ) THEN
                    BACKOUT( J ) = 1.0/DENOM
                 ELSE
                    BACKOUT( J ) = 0.0
                 END IF

              END DO ! end source loop

           END IF

C.............................................................................
C...........  Apply /MACT/ packet controls if present for the current
C             pollutant
C.............................................................................
           IF ( MFLAG .AND. PCTLFLAG( I, 4 ) ) THEN

C...............  Loop through sources
              DO S = 1, NSRC
              
                 E1  = DATVAL( S, E )
                 FAC = 1.

C................  Read temporary input file indices
                 READ( MDEV,* ) MACINDX
                 
C................  If MACT packet applies to this source, compute factor
                 IF ( MACINDX .GT. 0 ) THEN

C......................  Calculate inventory baseline efficiency
                    CTLEFF = 0.
                    RULEFF = 1.
                    RULPEN = 1.
                    IF ( NCE .GT. 0 ) CTLEFF = DATVAL( S,NCE )
                    IF ( NRE .GT. 0 ) RULEFF = DATVAL( S,NRE )
                    IF ( NRP .GT. 0 ) RULPEN = DATVAL( S,NRP )
                    INVEFF = CTLEFF * RULEFF * RULPEN

                    EXSTCEFF = MACEXEFF( MACINDX )
                    NEWCEFF  = MACNWEFF( MACINDX )
                    NEWFRAC  = MACNWFRC( MACINDX )

C.....................  Compute factor for existing and new sources
                    FAC = (1-NEWFRAC) * ((1-EXSTCEFF)/(1-INVEFF)) + 
     &                    (NEWFRAC) * ((1-NEWCEFF)/(1-INVEFF))

C...................  Overwrite temporary file line with new info
                    E2 = E1 * FAC
                    FACTOR( S ) = FACTOR( S ) * FAC
                    
                    WRITE( ODEV(4),93300 ) 1, PNAM, E1, E2, FAC
                    APPLFLAG = .TRUE.
                    
                    IF( FAC .GT. 1. ) THEN
                        CSRC = CSOURC( S )
                        CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )
                        WRITE( MESG,94110 ) 'WARNING: MACT ' //
     &                         'packet record number', MACINDX,
     &                         'is increasing ' // CRLF() // BLANK10 //
     &                         'emissions by factor', FAC, 'for:'
     &                         // CRLF() // BLANK10 //
     &                         BUFFER( 1:L2 ) // ' POL:' // PNAM
                        CALL M3MESG( MESG )
                    END IF               
                 ELSE
                    WRITE( ODEV(4),93300 ) 0, 'D', 0., 0., 0.
                 
                 END IF
                 
              END DO ! end source loop
              
           END IF
          
C.............................................................................
C...........  Apply /CONTROL/ packet controls if present for the current 
C             pollutant
C.............................................................................
           IF ( CFLAG .AND. PCTLFLAG( I, 1 ) ) THEN

C...............  Loop through sources
              DO S = 1, NSRC

                 E1  = DATVAL( S,E )
                 FAC = 1.

C................  Read temporary input file indices
                 READ( CDEV,* ) CTLINDX

C................  If control packet applies to this source, compute factor
                 IF ( CTLINDX .GT. 0 ) THEN
                    CTLEFF = FACCEFF( CTLINDX )
                    RULEFF = FACREFF( CTLINDX )
                    RULPEN = FACRLPN( CTLINDX )

C.....................  Check if this is a "replace" entry                    
                    IF( CTLRPLC( CTLINDX ) ) THEN
                        FAC = BACKOUT( S )*
     &                        ( 1.0 - CTLEFF*RULEFF*RULPEN )
                        FACTOR( S ) = FAC
                    ELSE
                        FAC = ( 1.0 - CTLEFF*RULEFF*RULPEN )
                        FACTOR( S ) = FACTOR( S ) * FAC
                    END IF

C...................  Overwrite temporary file line with new info
                    E2 = E1 * FAC                   
                    
                    WRITE( ODEV(1),93300 ) 1, PNAM, E1, E2, FAC
                    APPLFLAG = .TRUE.

                    IF( FAC .GT. 1. ) THEN
                        CSRC = CSOURC( S )
                        CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )
                        WRITE( MESG,94110 ) 'WARNING: CONTROL '//
     &                         'packet record number', CTLINDX, 
     &                         'is increasing ' // CRLF()// BLANK10//
     &                         'emissions by factor', FAC, 'for:'
     &                         //CRLF()// BLANK10//
     &                         BUFFER( 1:L2 ) // ' POL:' // PNAM
                        CALL M3MESG( MESG )
                    END IF

C..................  Overwrite temporary file line with new info
                 ELSE
                    WRITE( ODEV(1),93300 ) 0, 'D', 0., 0., 0.

                 END IF

              END DO ! end source loop

           END IF

C.............................................................................
C...........  Apply /EMSCONTROL/ packet controls if present for the current 
C             pollutant
C.............................................................................
C...........  NOTE - SFLAG and CFLAG cannot both be true
           IF ( SFLAG .AND. PCTLFLAG( I, 1 ) ) THEN

              DO S = 1, NSRC

                 E1  = DATVAL( S,E )
                 FAC = 1.

C................  Read temporary input file indices
                 READ( CDEV,* ) CTLINDX

C................  EMS CONTROL packet applies to this source, compute factor
                 IF ( CTLINDX .GT. 0 ) THEN
                    IF( EMSTOTL( CTLINDX ) .NE. 0. ) THEN
                       FAC = EMSTOTL( CTLINDX )

                    ELSE
                       CTLEFF = EMSCEFF( CTLINDX )
                       RULEFF = EMSREFF( CTLINDX )
                       RULPEN = EMSRLPN( CTLINDX )
                       FAC = BACKOUT(CTLINDX)*EMSPTCF(CTLINDX)* 
     &                       (1.- CTLEFF*RULEFF*RULPEN)

                    END IF

C..................  Write output temporary file line with new info
                    E2 = E1 * FAC
                    FACTOR( S ) = FACTOR( S ) * FAC
                    
                    WRITE( ODEV(1),93300 ) 1, PNAM, E1, E2, FAC
                    APPLFLAG = .TRUE.

                    IF( FAC .GT. 1. ) THEN
                        CSRC = CSOURC( S )
                        CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )
                        WRITE( MESG,94110 ) 'WARNING: EMS_CONTROL '//
     &                         'packet record number', CTLINDX, 
     &                         'is increasing ' // CRLF()// BLANK10//
     &                         'emissions by factor', FAC, 'for:'
     &                         //CRLF()// BLANK10//
     &                         BUFFER( 1:L2 ) // ' POL:' // PNAM
                        CALL M3MESG( MESG )
                    END IF

C..................  Write output temporary file line with placeholder info
                 ELSE
                    WRITE( ODEV(1),93300 ) 0, 'D', 0., 0., 0.

                 END IF

              END DO ! end source loop

           END IF

C.............................................................................
C............  Apply /CTG/ packet
C.............................................................................
           IF ( GFLAG .AND. PCTLFLAG( I, 2 ) ) THEN

C...............  Compute CTG factor
              DO S = 1, NSRC

                 E1  = DATVAL( S,E ) * FACTOR( S )
                 FAC = 1.

C................  Read CTG packet index from input temporary file
                 READ( GDEV,* ) CTGINDX

C................  If CTG packet applies to this source, compute factor
                 IF ( CTGINDX .GT. 0 ) THEN
                    CUTOFF = CUTCTG ( CTGINDX )
                    CTGFAC = FACCTG ( CTGINDX )
                    MACT   = FACMACT( CTGINDX )
                    RACT   = FACRACT( CTGINDX )

C.....................  Check to see if emissions exceed cutoff and if 
C                       necessary, apply controls
C.....................  The comparison emission value already has controls
C                       from the /CONTROL/ packet
                    IF ( E1 .GT. CUTOFF ) THEN

C........................  Initialize CTG factor with base factor from packet
                       FAC = CTGFAC

C........................  Compute output emissions with /CONTROL/ and base CTG 
                       E2  = E1*CTGFAC

C........................  If emissions still exceed cutoff, apply second
C                          CTG factor
                       IF ( E2 .GT. CUTOFF ) THEN

C...........................  Use MACT factor if it is defined 
                          IF ( MACT .GT. 0 ) THEN
                             CTGFAC2 = MACT

C...........................  Otherwise, use RACT factor 
                          ELSE IF ( RACT .GT. 0 ) THEN
                             CTGFAC2 = RACT

C...........................  Otherwise, set to cutoff value 
                          ELSE
                             CTGFAC2 = CUTOFF / E2

                          END IF

                          FAC = FAC * CTGFAC2
                          E2  = E2  * CTGFAC2

                       END IF

C........................  Compute aggregate factor for current source
                       FACTOR( S ) = FACTOR( S ) * FAC

C........................  Write output temporary file line with new info
                       WRITE( ODEV(2),93300 ) 1, PNAM, E1, E2, FAC
                       APPLFLAG = .TRUE.

C.........................  Write warning if emissions have increased
                        IF( FAC .GT. 1. ) THEN
                            CSRC = CSOURC( S )
                            CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )
                            WRITE( MESG,94110 ) 'WARNING: CTG '//
     &                         'packet record number', CTGINDX, 
     &                         'is increasing ' // CRLF()// BLANK10//
     &                         'emissions by factor', FAC, 'for:' //
     &                         CRLF()// BLANK10//
     &                         BUFFER( 1:L2 ) // ' POL:' // PNAM
                            CALL M3MESG( MESG )
                        END IF

C.....................  If no controls, then write output temporary line only
                    ELSE
                       WRITE( ODEV(2),93300 ) 0, 'D', 0., 0., 0.

                    END IF

                 ELSE ! If K = 0 (for sources not having applied "CTG"

                     WRITE( ODEV(2),93300 ) 0, 'D', 0., 0., 0.

                 END IF

              END DO ! end source loop

           END IF

C.............................................................................
C............  Apply /ALLOWABLE/ packet
C.............................................................................
           IF ( LFLAG .AND. PCTLFLAG( I, 3 ) ) THEN

C...........  Process ALW packet
              DO S = 1, NSRC

                 E1 = DATVAL( S,E )

C.................  Read allowable packet index from input tmp file
                 READ( LDEV,* ) ALWINDX

                 FAC = 1.
C..................  If ALLOWABLE packet applies to this source, compute factor
                 IF ( ALWINDX .GT. 0 ) THEN
                    CAP     = EMCAPALW( ALWINDX )
                    REPLACE = EMREPALW( ALWINDX )

C.....................  Both Cap value and Replace value are defined, then
C                       compare emissions to Cap and set factor with Replace.
                    IF ( CAP .GE. 0. .AND. REPLACE .GE. 0. ) THEN

                       IF ( DATVAL( S,E ) .GT. CAP ) THEN
                          FAC = REPLACE/DATVAL( S,E )
                       END IF

C.....................  Only Cap value is defined, then compare emissions to Cap
C                       set factor with Cap
                    ELSE IF ( CAP .GE. 0. .AND. REPLACE .LT. 0. ) THEN

                       IF ( DATVAL( S,E ) .GT. CAP ) THEN
                          FAC = CAP/DATVAL( S,E )
                       END IF

C.....................  Only Replace value is defined, then set factor with
C                       Replace.
                    ELSE IF ( CAP .LT. 0. .AND. REPLACE .GE. 0. ) THEN

                       IF ( DATVAL( S,E ) .GT. REPLACE ) THEN
                          FAC = REPLACE/DATVAL( S,E )
                       END IF
                       
                    END IF

C.....................  Write output temporary file line with new info
                    E2 = E1 * FAC
                    FACTOR( S ) = FACTOR( S ) * FAC

                    IF( FAC .NE. 1. ) THEN
                        WRITE( ODEV(3),93300 ) 1, PNAM, E1, E2, FAC
                        APPLFLAG = .TRUE.

C.........................  Write warning if emissions have increased
                        IF( FAC .GT. 1. ) THEN
                            CSRC = CSOURC( S )
                            CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )
                            WRITE( MESG,94110 ) 'WARNING: ALLOWABLE '//
     &                         'packet record number', ALWINDX, 
     &                         'is increasing ' // CRLF()// BLANK10//
     &                         'emissions by factor', FAC, 'for:' //
     &                         CRLF()// BLANK10//
     &                         BUFFER( 1:L2 ) // ' POL:' // PNAM
                            CALL M3MESG( MESG )
                        END IF

                    ELSE
                        WRITE( ODEV(3),93300 ) 0, 'D', 0., 0., 0.
                    END IF

C..................  If no controls, then write output temporary line only
                 ELSE
                     WRITE( ODEV(3),93300 ) 0, 'D', 0., 0., 0.

                 END IF

                END DO ! end source loop

            END IF

C.............  Store output emissions for groups
C.............  This must be in a separate loop to account for all possible
C               combinations of packets
            DO S = 1, NSRC

                E1 = DATVAL( S,E )
                E2 = E1 * FACTOR( S )
                J  = GRPINDX( S )
                GRPOUTEM( J,I ) = GRPOUTEM( J,I ) + E2

C.................  Flag group if emissions are different
                IF( E1 .NE. E2 ) GRPFLAG( J ) = .TRUE.

            END DO

C.............  Open control matrix, if needed and if not opened before
            IF( APPLFLAG .AND. .NOT. OPENFLAG ) THEN 
                CALL OPENCMAT( ENAME, 'MULTIPLICATIVE', MNAME )
                OPENFLAG = .TRUE.
            END IF

C.............  Write multiplicative controls for current pollutant
            IF( OPENFLAG ) THEN
                IF( .NOT. WRITESET( MNAME, PNAM, ALLFILES, 0, 0, 
     &                              FACTOR )                     ) THEN
                    MESG = 'Failed to write multiplicative control ' // 
     &                     'factors for pollutant ' // PNAM
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF
            END IF

        END DO ! end pollutant loop

C.........  Write out controlled facilities report for point sources
        IF( APPLFLAG ) THEN
            WRITE( RDEV, 93000 ) 'Processed as '// CATDESC// ' sources'
            IF ( PYEAR .GT. 0 ) THEN
                WRITE( RDEV, 93390 ) 'Projected inventory year ', PYEAR
            ELSE
                WRITE( RDEV, 93390 ) 'Base inventory year ', BYEAR
            END IF
            IF( MFLAG ) WRITE( RDEV, 93000 )
     &                  'Controls applied with /MACT/ packet'
            IF( CFLAG ) WRITE( RDEV, 93000 ) 
     &                  'Controls applied with /CONTROL/ packet'
            IF( SFLAG ) WRITE( RDEV, 93000 ) 
     &                  'Controls applied with /EMS_CONTROL/ packet'
            IF( GFLAG ) WRITE( RDEV, 93000 ) 
     &                  'Controls applied with /CTG/ packet'
            IF( LFLAG ) WRITE( RDEV, 93000 ) 
     &                  'Controls applied with /ALLOWABLE/ packet'
            IF( LAVEDAY ) THEN
                WRITE( RDEV,93000 ) 'Average day data basis in report'
            ELSE
                WRITE( RDEV,93000 ) 'Annual total data basis in report'
            END IF

            IF ( CATEGORY .EQ. 'POINT' ) THEN
                WRITE( RDEV, 93000 ) 
     &             'Emissions by controlled facility before and ' //
     &             'after controls'
            ELSE
                WRITE( RDEV, 93000 )
     &             'Emissions by controlled state/SCC before and ' //
     &             'after controls'
            END IF

            IF ( CATEGORY .EQ. 'POINT' ) THEN
                WRITE( RDEV, 93400 ) 
     &               ( PNAMMULT( I ), PNAMMULT( I ), I=1,NVCMULT )
            ELSE
                WRITE( RDEV, 93402 ) 
     &               ( PNAMMULT( I ), PNAMMULT( I ), I=1,NVCMULT )
            END IF

            PNAM = '[tons/day]'
            WRITE( RDEV, 93405 ) ( PNAM, PNAM, I=1,NVCMULT )
            
            I = 26 + NVCMULT * 43
            WRITE( RDEV,93000 ) REPEAT( '-', I )
 
            PIDX = 0
            DO S = 1, NSRC
                K   = GRPSTIDX( S )
                IDX = GRPINDX ( K )

                IF( IDX .NE. PIDX .AND.
     &              GRPFLAG( IDX )      ) THEN

                    J = FIPLEN3 + 1
                    SELECT CASE( CATEGORY )
                    CASE ( 'AREA' , 'MOBILE' )
                        CSRC = GRPCHAR( S )
                        WRITE( RDEV, 93410 ) 
     &                      CSRC( 1:STALEN3 ), CSRC( SCCBEG:SCCEND ),
     &                      ( GRPINEM ( IDX,I ), GRPOUTEM( IDX,I ),
     &                        I = 1, NVCMULT )
                    CASE ( 'POINT' )                 
                        CSRC = CSOURC( S )
                        WRITE( RDEV, 93412 ) 
     &                      CSRC( 1:FIPLEN3 ), CSRC( J:FPLLEN3 ),
     &                      ( GRPINEM ( IDX,I ), GRPOUTEM( IDX,I ),
     &                        I = 1, NVCMULT )
                    END SELECT

                    PIDX = IDX
                END IF
            END DO

        END IF

        IF( .NOT. APPLFLAG ) THEN

            MESG = 'WARNING: No MACT, CONTROL, EMS_CONTROL, CTG, or ' //
     &             'ALLOWABLE packet entries match inventory.'
            CALL M3MSG2( MESG )

            MESG = 'WARNING: Multiplicative control will not be output!'
            CALL M3MSG2( MESG )

            WRITE( RDEV, 93000 ) 'No MACT, CONTROL, EMS_CONTROL, ' //
     &             'CTG, or ALLOWABLE packet entries matched inventory.'

        END IF

C........  Change input temporary file unit numbers to be output files for
C          report processing.
        IF( CDEV .GT. 0 ) CDEV = ODEV( 1 )
        IF( GDEV .GT. 0 ) GDEV = ODEV( 2 )
        IF( LDEV .GT. 0 ) LDEV = ODEV( 3 )
        IF( MDEV .GT. 0 ) MDEV = ODEV( 4 )

C.........  Deallocate local memory
        DEALLOCATE( BACKOUT, DATVAL, FACTOR )

        DEALLOCATE( GRPINDX, GRPFLAG, GRPINEM, GRPOUTEM )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

93300   FORMAT( I2, 1X, '"', A, '"', 3( 1X, E12.5 ) )

93390   FORMAT( A, I4.4 )

93400   FORMAT( ' Region;', 5X, 'Facility ID;', 1X, 
     &          100( '  In ', A16, ';', 1X, 'Out ', A16, :, ';' ) )

93402   FORMAT( '  State;', 5X, '        SCC;', 1X, 
     &          100( '  In ', A16, ';', 1X, 'Out ', A16, :, ';' ) )

93405   FORMAT( 7X, ';', 16X, ';', 1X
     &          100( 2X, A16, 3X, ';', 1X, A16, :, 4X, ';' ))

93410   FORMAT( 4X, A3, ';', 6X, A10, ';', 1X, 
     &          100( 10X, E11.4, :, ';' ))

93412   FORMAT( 1X, A6, ';', 1X, A15, ';', 1X, 
     &          100( 10X, E11.4, :, ';' ))

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94110   FORMAT( A, 1X, I8, 1X, 5( A, :, E11.3, :, 1X ) )

C******************  INTERNAL SUBPROGRAMS  *****************************

        CONTAINS

C.............  This internal subprogram writes and error message
C               and then terminates program execution if an error
C               is encountered reading control information from the
C               inventory file
            SUBROUTINE WRITE_MESG_EXIT( OUTNAME, PROGNAME )

C.............  Subprogram arguments
            CHARACTER*(*), INTENT (IN) :: OUTNAME   ! name of inventory
                                                    ! variable that generated
                                                    ! the error
            CHARACTER*16,  INTENT (IN) :: PROGNAME  ! name of calling subroutine

C.............  Local variables
            CHARACTER* 300   MESG                   ! message buffer

C----------------------------------------------------------------------

            MESG = 'Error reading ' // OUTNAME // ' from inventory file'

            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

            END SUBROUTINE WRITE_MESG_EXIT

C----------------------------------------------------------------------

        END SUBROUTINE GENMULTC
