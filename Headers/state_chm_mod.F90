!------------------------------------------------------------------------------
!                  GEOS-Chem Global Chemical Transport Model                  !
!------------------------------------------------------------------------------
!BOP
!
! !MODULE: state_chm_mod
!
! !DESCRIPTION: Module STATE\_CHM\_MOD contains the derived type
!  used to define the Chemistry State object for GEOS-Chem.
!\\
!\\
!  This module also contains the routines that allocate and deallocate memory 
!  to the Chemistry State object.  The chemistry state object is not defined
!  in this module.  It must be be declared as variable in the top-level 
!  driver routine, and then passed to lower-level routines as an argument.
!\\
!\\
! !INTERFACE: 
!
MODULE State_Chm_Mod
!
! USES:
!
  USE PhysConstants    ! Physical constants
  USE Precision_Mod    ! GEOS-Chem precision types 
  USE Species_Mod      ! For species database object

  IMPLICIT NONE
  PRIVATE
!
! !PUBLIC MEMBER FUNCTIONS:
!
  PUBLIC :: Ind_
  PUBLIC :: Init_State_Chm
  PUBLIC :: Cleanup_State_Chm
!
! !PRIVATE DATA MEMBERS:
!
  TYPE(SpcPtr), PRIVATE, POINTER :: SpcDataLocal(:)  ! Local version of StateChm for  
!
! !PUBLIC DATA MEMBERS:
!
  !=========================================================================
  ! Derived type for Chemistry State
  !=========================================================================
  TYPE, PUBLIC :: ChmState

     ! Count of each type of species
     INTEGER                    :: nSpecies             ! # of species
     INTEGER                    :: nAdvect              ! # of advected species
     INTEGER                    :: nDryDep              ! # of drydep species
     INTEGER                    :: nKppSpc              ! # of KPP chem species
     INTEGER                    :: nWetDep              ! # of wetdep species

     ! Mapping vectors to subset types of species
     INTEGER,           POINTER :: Map_Advect (:      ) ! Advected species ID's
     INTEGER,           POINTER :: Map_DryDep (:      ) ! Drydep species ID's
     INTEGER,           POINTER :: Map_KppSpc (:      ) ! KPP chem species ID's
     INTEGER,           POINTER :: Map_WetDep (:      ) ! Wetdep species IDs'

     ! Physical properties & indices for each species
     TYPE(SpcPtr),      POINTER :: SpcData    (:      ) ! GC Species database

     ! Chemical species
     INTEGER,           POINTER :: Spec_Id    (:      ) ! Species ID # 
     CHARACTER(LEN=14), POINTER :: Spec_Name  (:      ) ! Species names
     REAL(fp),          POINTER :: Species    (:,:,:,:) ! Species [molec/cm3]
     CHARACTER(LEN=20)          :: Spc_Units            ! Species units

     ! Aerosol quantities
     INTEGER                    :: nAero                ! # of Aerosol Types
     REAL(fp),          POINTER :: AeroArea   (:,:,:,:) ! Aerosol Area [cm2/cm3]
     REAL(fp),          POINTER :: AeroRadi   (:,:,:,:) ! Aerosol Radius [cm]
     REAL(fp),          POINTER :: WetAeroArea(:,:,:,:) ! Aerosol Area [cm2/cm3]
     REAL(fp),          POINTER :: WetAeroRadi(:,:,:,:) ! Aerosol Radius [cm]

     ! pH and alkalinity
     Real(fp),          POINTER :: pHCloud    (:,:,:  ) ! Cloud pH [-]
     Real(fp),          POINTER :: SSAlk      (:,:,:,:) ! Sea-salt alkalinity [-]

#if defined( ESMF_ )
     ! Chemical rates & rate parameters
     INTEGER,           POINTER :: JLOP       (:,:,:  ) ! 1-D SMVGEAR index
     INTEGER,           POINTER :: JLOP_PREV  (:,:,:  ) ! JLOP, prev timestep
#endif

     ! Fields for UCX mechanism
     REAL(f4),          POINTER :: STATE_PSC  (:,:,:  ) ! PSC type (see Kirner
                                                        !  et al. 2011, GMD)
     REAL(fp),          POINTER :: KHETI_SLA  (:,:,:,:) ! Strat. liquid aerosol
                                                        !  reaction cofactors
     ! For the tagged Hg simulation
     INTEGER                    :: N_HG_CATS            ! # of Hg categories
     INTEGER,           POINTER :: Hg0_Id_List(:      ) ! Hg0 cat <-> tracer #
     INTEGER,           POINTER :: Hg2_Id_List(:      ) ! Hg2 cat <-> tracer #
     INTEGER,           POINTER :: HgP_Id_List(:      ) ! HgP cat <-> tracer #
     CHARACTER(LEN=4),  POINTER :: Hg_Cat_Name(:      ) ! Category names

  END TYPE ChmState
!
! !REMARKS:
!                                                                             
! !REVISION HISTORY:
!  19 Oct 2012 - R. Yantosca - Initial version, based on "gc_type2_mod.F90"
!  26 Oct 2012 - R. Yantosca - Add fields for stratospheric chemistry
!  26 Feb 2013 - M. Long     - Add DEPSAV to derived type ChmState
!  07 Mar 2013 - R. Yantosca - Add Register_Tracer subroutine
!  07 Mar 2013 - R. Yantosca - Now make POSITION a locally SAVEd variable
!  20 Aug 2013 - R. Yantosca - Removed "define.h", this is now obsolete
!  19 May 2014 - C. Keller   - Removed Trac_Btend. DepSav array covers now
!                              all species.
!  03 Dec 2014 - M. Yannetti - Added PRECISION_MOD
!  11 Dec 2014 - R. Yantosca - Keep JLOP and JLOP_PREV for ESMF runs only
!  17 Feb 2015 - E. Lundgren - New tracer units kg/kg dry air (previously kg)
!  13 Aug 2015 - E. Lundgren - Add tracer units string to ChmState derived type 
!  28 Aug 2015 - R. Yantosca - Remove strat chemistry fields, these are now
!                              handled by the HEMCO component
!  05 Jan 2016 - E. Lundgren - Use global physical constants
!  28 Jan 2016 - M. Sulprizio- Add STATE_PSC, KHETI_SLA. These were previously
!                              local arrays in ucx_mod.F, but now need to be
!                              accessed in gckpp_HetRates.F90.
!  12 May 2016 - M. Sulprizio- Add WetAeroArea, WetAeroRadi to replace 1D arrays
!                              WTARE, WERADIUS previously in comode_mod.F
!  18 May 2016 - R. Yantosca - Add mapping vectors for subsetting species
!  07 Jun 2016 - M. Sulprizio- Remove routines Get_Indx, Register_Species, and
!                              Register_Tracer made obsolete by the species
!                              database.
!  22 Jun 2016 - R. Yantosca - Rename Id_Hg0 to Hg0_Id_List, Id_Hg2 to
!                              Hg2_Id_List, and Id_HgP to HgP_Id_List
!  16 Aug 2016 - M. Sulprizio- Rename from gigc_state_chm_mod.F90 to
!                              state_chm_mod.F90. The "gigc" nomenclature is
!                              no longer used.
!  23 Aug 2016 - M. Sulprizio- Remove tracer fields from State_Chm. These are
!                              now entirely replaced with the species fields.
!EOP
!------------------------------------------------------------------------------
!BOC
CONTAINS
!EOC
!------------------------------------------------------------------------------
!                  GEOS-Chem Global Chemical Transport Model                  !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: ind_
!
! !DESCRIPTION: Function IND\_ returns the index of an advected species or 
!  chemical species contained in the chemistry state object by name.
!\\
!\\
! !INTERFACE:
!
  FUNCTION Ind_( name, flag ) RESULT( Indx )
!
! !USES:
!
    USE CHARPAK_MOD, ONLY : TRANUC
!
! !INPUT PARAMETERS:
!
    CHARACTER(LEN=*),           INTENT(IN) :: name  ! Species name
    CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: flag  ! Species type
!
! !RETURN VALUE:
!
    INTEGER                                :: Indx  ! Index of this species 
!
! !REMARKS
!
! !REVISION HISTORY: 
!  07 Oct 2016 - M. Long     - Initial version
!  15 Jun 2016 - M. Sulprizio- Make species name uppercase before computing hash
!  17 Aug 2016 - M. Sulprizio- Tracer flag 'T' is now advected species flag 'A'
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
    INTEGER           :: N, Hash
    CHARACTER(LEN=14) :: Name14

    !=====================================================================
    ! Ind_ begins here!
    !=====================================================================

    ! Initialize the output value
    Indx   = -1

    ! Make species name uppercase for hash algorithm
    Name14 = Name
    CALL TRANUC( Name14 )

    ! Compute the hash corresponding to the given species name
    Hash   = Str2Hash( Name14 )

    ! Loop over all entries in the Species Database object
    DO N = 1, SIZE( SpcDataLocal )

       ! Compare the hash we just created against the list of
       ! species name hashes stored in the species database
       IF( Hash == SpcDataLocal(N)%Info%NameHash  ) THEN

          IF (.not. PRESENT(Flag)) THEN

             ! Default to Species/ModelID
             Indx = SpcDataLocal(N)%Info%ModelID
             RETURN

          ELSE

             ! Only need first character of the flag for this.
             IF     (flag(1:1) .eq. 'S' .or. flag(1:1) .eq. 's') THEN

                ! Species/ModelID
                Indx = SpcDataLocal(N)%Info%ModelID
                RETURN

             ELSEIF (flag(1:1) .eq. 'A' .or. flag(1:1) .eq. 'a') THEN

                ! Advected species flag
                Indx = SpcDataLocal(N)%Info%AdvectID
                RETURN

             ELSEIF (flag(1:1) .eq. 'K' .or. flag(1:1) .eq. 'k') THEN

                ! KPP species ID
                Indx = SpcDataLocal(N)%Info%KppSpcId
                RETURN

             ELSEIF (flag(1:1) .eq. 'V' .or. flag(1:1) .eq. 'v') THEN

                ! KPP VAR ID
                Indx = SpcDataLocal(N)%Info%KppVarId
                RETURN

             ELSEIF (flag(1:1) .eq. 'F' .or. flag(1:1) .eq. 'f') THEN

                ! KPP FIX ID
                Indx = SpcDataLocal(N)%Info%KppFixId
                RETURN

             ELSEIF (flag(1:1) .eq. 'W' .or. flag(1:1) .eq. 'w') THEN

                ! WetDep ID
                Indx = SpcDataLocal(N)%Info%WetDepId
                RETURN

             ELSEIF (flag(1:1) .eq. 'D' .or. flag(1:1) .eq. 'd') THEN

                ! DryDep ID
                Indx = SpcDataLocal(N)%Info%DryDepId
                RETURN

             ENDIF

          ENDIF
          EXIT

       ENDIF

    ENDDO

    RETURN

  END FUNCTION Ind_
!EOC
!------------------------------------------------------------------------------
!                  GEOS-Chem Global Chemical Transport Model                  !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_state_chm
!
! !DESCRIPTION: Routine INIT\_STATE\_CHM allocates and initializes the 
!  pointer fields of the chemistry state object.
!\\
!\\
! !INTERFACE:
!
  SUBROUTINE Init_State_Chm( am_I_Root, IM,        JM,         &   
                             LM,        Input_Opt, State_Chm,  &
                             nAerosol,  RC         )
!
! !USES:
!
    USE ErrCode_Mod
    USE GCKPP_Parameters,     ONLY : NSPEC
    USE Input_Opt_Mod,        ONLY : OptInput
    USE Species_Mod,          ONLY : Species
    USE Species_Mod,          ONLY : Spc_GetNumSpecies
    USE Species_Database_Mod, ONLY : Init_Species_Database
!
! !INPUT PARAMETERS:
! 
    LOGICAL,        INTENT(IN)    :: am_I_Root   ! Is this the root CPU?
    INTEGER,        INTENT(IN)    :: IM          ! # longitudes on this PET
    INTEGER,        INTENT(IN)    :: JM          ! # longitudes on this PET
    INTEGER,        INTENT(IN)    :: LM          ! # longitudes on this PET
    INTEGER,        INTENT(IN)    :: nAerosol    ! # aerosol species
!
! !INPUT/OUTPUT PARAMETERS:
!
    TYPE(OptInput), INTENT(INOUT) :: Input_Opt   ! Input Options object
    TYPE(ChmState), INTENT(INOUT) :: State_Chm   ! Chemistry State object
!
! !OUTPUT PARAMETERS:
!
    INTEGER,        INTENT(OUT)   :: RC          ! Return code
!
! !REMARKS:
!  In the near future we will put some error trapping on the allocations
!  so that we can stop the simulation if the allocations cannot be made.
! 
! !REVISION HISTORY: 
!  19 Oct 2012 - R. Yantosca - Renamed from gc_type2_mod.F90
!  19 Oct 2012 - R. Yantosca - Now pass all dimensions as arguments
!  26 Oct 2012 - R. Yantosca - Now allocate Strat_P, Strat_k fields
!  26 Oct 2012 - R. Yantosca - Add nSchem, nSchemBry as arguments
!  01 Nov 2012 - R. Yantosca - Don't allocate strat chem fields if nSchm=0
!                              and nSchmBry=0 (i.e. strat chem is turned off)
!  26 Feb 2013 - M. Long     - Now pass Input_Opt via the argument list
!  26 Feb 2013 - M. Long     - Now allocate the State_Chm%DEPSAV field
!  11 Dec 2014 - R. Yantosca - Remove TRAC_TEND and DEPSAV fields
!  13 Aug 2015 - E. Lundgren - Initialize trac_units to ''
!  28 Aug 2015 - R. Yantosca - Remove stratospheric chemistry fields; 
!                              these are all now read in via HEMCO
!  28 Aug 2015 - R. Yantosca - Also initialize the species database object
!  09 Oct 2015 - R. Yantosca - Bug fix: set State_Chm%SpcData to NULL
!  16 Dec 2015 - R. Yantosca - Now overwrite the Input_Opt%TRACER_MW_G and
!                              related fields w/ info from species database
!  29 Apr 2016 - R. Yantosca - Don't initialize pointers in declaration stmts
!  02 May 2016 - R. Yantosca - Nullify Hg index fields for safety's sake
!  18 May 2016 - R. Yantosca - Now determine the # of each species first,
!                              then allocate fields of State_Chm
!  18 May 2016 - R. Yantosca - Now populate the species mapping vectors
!  30 Jun 2016 - M. Sulprizio- Remove nSpecies as an input argument. This is now
!                              initialized as the size of SpcData.
!  22 Jul 2016 - E. Lundgren - Initialize spc_units to ''
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
    ! Scalars
    INTEGER                :: N,          C
    INTEGER                :: N_Hg0_CATS, N_Hg2_CATS, N_HgP_CATS

    ! Pointers
    TYPE(Species), POINTER :: ThisSpc

    ! Assume success until otherwise
    RC = GC_SUCCESS

    !=====================================================================
    ! Initialization
    !=====================================================================

    ! Number of each type of species
    State_Chm%nSpecies    =  0
    State_Chm%nAdvect     =  0
    State_Chm%nDryDep     =  0
    State_Chm%nKppSpc     =  0
    State_Chm%nWetDep     =  0

    ! Mapping vectors for subsetting each type of species
    State_Chm%Map_Advect  => NULL()
    State_Chm%Map_DryDep  => NULL()
    State_Chm%Map_KppSpc  => NULL()
    State_Chm%Map_WetDep  => NULL()

    ! Chemical species
    State_Chm%Spec_ID     => NULL()
    State_Chm%Spec_Name   => NULL()
    State_Chm%Species     => NULL()
    State_Chm%Spc_Units   = ''

    ! Species database
    State_Chm%SpcData     => NULL()
    ThisSpc               => NULL()

    ! Aerosol parameters
    State_Chm%nAero       = 0
    State_Chm%AeroArea    => NULL()
    State_Chm%AeroRadi    => NULL()
    State_Chm%WetAeroArea => NULL()
    State_Chm%WetAeroRadi => NULL()

    ! pH/alkalinity
    State_Chm%pHCloud     => NULL()
    State_Chm%SSAlk       => NULL()

    ! Hg species indexing
    N_Hg0_CATS            =  0
    N_Hg2_CATS            =  0
    N_HgP_CATS            =  0
    State_Chm%N_Hg_CATS   =  0
    State_Chm%Hg_Cat_Name => NULL()
    State_Chm%Hg0_Id_List      => NULL()
    State_Chm%Hg2_Id_List      => NULL()
    State_Chm%HgP_Id_List      => NULL()

    !=====================================================================
    ! Populate the species database object field
    ! (assumes Input_Opt has already been initialized)
    !=====================================================================
    CALL Init_Species_Database( am_I_Root = am_I_Root,          &
                                Input_Opt = Input_Opt,          &
                                SpcData   = State_Chm%SpcData,  &
                                RC        = RC                 )

    !=====================================================================
    ! Determine the number of advected, drydep, wetdep, and total species
    !=====================================================================

    ! The total number of species is the size of SpcData
    State_Chm%nSpecies = SIZE( State_Chm%SpcData )

    ! Get the number of advected, dry-deposited, KPP chemical species,
    ! and and wet-deposited species.  Also return the # of Hg0, Hg2, and 
    ! HgP species (these are zero unless the Hg simulation is used).
    CALL Spc_GetNumSpecies( State_Chm%nAdvect,  &
                            State_Chm%nDryDep,  &
                            State_Chm%nKppSpc,  &
                            State_Chm%nWetDep,  &
                            N_Hg0_CATS,         &
                            N_Hg2_CATS,         &
                            N_HgP_CATS         )

    !=====================================================================
    ! Allocate and initialize mapping vectors to subset species
    !=====================================================================

    ALLOCATE( State_Chm%Map_Advect(             State_Chm%nAdvect  ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Map_Advect = 0

    ALLOCATE( State_Chm%Map_Drydep(             State_Chm%nDryDep  ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Map_DryDep = 0

    ALLOCATE( State_Chm%Map_KppSpc(             NSPEC              ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Map_KppSpc = 0

    ALLOCATE( State_Chm%Map_WetDep(             State_Chm%nWetDep  ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Map_WetDep = 0

    !=====================================================================
    ! Allocate and initialize chemical species fields
    !=====================================================================

    ALLOCATE( State_Chm%Spec_Id   (             State_Chm%nSpecies ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Spec_Id = 0

    ALLOCATE( State_Chm%Spec_Name (             State_Chm%nSpecies ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Spec_Name = ''

    ALLOCATE( State_Chm%Species   ( IM, JM, LM, State_Chm%nSpecies ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%Species = 0e+0_fp

    !=====================================================================
    ! Allocate and initialize aerosol fields
    !=====================================================================

    State_Chm%nAero = nAerosol

    ALLOCATE( State_Chm%AeroArea   ( IM, JM, LM, State_Chm%nAero   ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%AeroArea = 0e+0_fp

    ALLOCATE( State_Chm%AeroRadi   ( IM, JM, LM, State_Chm%nAero   ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%AeroRadi = 0e+0_fp

    ALLOCATE( State_Chm%WetAeroArea( IM, JM, LM, State_Chm%nAero   ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%WetAeroArea = 0e+0_fp

    ALLOCATE( State_Chm%WetAeroRadi( IM, JM, LM, State_Chm%nAero   ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%WetAeroRadi = 0e+0_fp

    !=====================================================================
    ! Allocate and initialize fields for halogen chemistry
    !=====================================================================
    
    ALLOCATE( State_Chm%pHCloud    ( IM, JM, LM                    ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%pHCloud = 0e+0_fp

    ALLOCATE( State_Chm%SSAlk      ( IM, JM, LM, 2                 ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%SSAlk = 0e+0_fp

    !=====================================================================
    ! Allocate and initialize fields for UCX mechamism
    !=====================================================================

    ALLOCATE( State_Chm%STATE_PSC ( IM, JM, LM                     ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%STATE_PSC = 0.0_f4

    ALLOCATE( State_Chm%KHETI_SLA ( IM, JM, LM, 11                 ), STAT=RC )
    IF ( RC /= GC_SUCCESS ) RETURN
    State_Chm%KHETI_SLA = 0.0_fp

    !=======================================================================
    ! Set up the species mapping vectors
    !=======================================================================
    IF ( am_I_Root ) THEN
       WRITE( 6,'(/,a)' ) 'ADVECTED SPECIES MENU'
       WRITE( 6,'(  a)' ) REPEAT( '-', 48 )
       WRITE( 6,'(  a)' ) '  # Species Name  g/mole'
    ENDIF

    ! Loop over all species
    DO N = 1, State_Chm%nSpecies

       ! GEOS-Chem Species Database entry for species # N
       ThisSpc => State_Chm%SpcData(N)%Info
 
       !--------------------------------------------------------------------
       ! Set up the mapping for ADVECTED SPECIES
       !--------------------------------------------------------------------
       IF ( ThisSpc%Is_Advected ) THEN

          ! Update the mapping vector of advected species
          C                         = ThisSpc%AdvectId
          State_Chm%Map_Advect(C)   = ThisSpc%ModelId
          
          ! Print to screen
          IF ( am_I_Root ) THEN
             WRITE( 6, 100 ) ThisSpc%ModelId, ThisSpc%Name, ThisSpc%MW_g
          ENDIF

       ENDIF

       !--------------------------------------------------------------------
       ! Set up the mapping for DRYDEP SPECIES
       !--------------------------------------------------------------------
       IF ( ThisSpc%Is_DryDep ) THEN
          C                         = ThisSpc%DryDepId
          State_Chm%Map_Drydep(C)   = ThisSpc%ModelId
       ENDIF

       !--------------------------------------------------------------------
       ! Set up the mapping for SPECIES IN THE KPP MECHANISM
       !--------------------------------------------------------------------
       IF ( ThisSpc%Is_Kpp ) THEN
          C                         = ThisSpc%KppSpcId
          State_Chm%Map_KppSpc(C)   = ThisSpc%ModelId
       ENDIF

       !--------------------------------------------------------------------
       ! Set up the mapping for SPECIES IN THE KPP MECHANISM
       !--------------------------------------------------------------------
       IF ( ThisSpc%Is_WetDep ) THEN
          C                         = ThisSpc%WetDepId
          State_Chm%Map_WetDep(C)   = ThisSpc%ModelId
       ENDIF

       ! Free pointer
       ThisSpc => NULL()

    ENDDO

    !=======================================================================
    ! Special handling for the Hg and tagHg  simulations: get the # of Hg
    ! categories for total & tagged tracers from the species database
    !=======================================================================
    IF ( Input_Opt%ITS_A_MERCURY_SIM ) THEN

       ! Hg0, Hg2, HgP should all have the same number of categories as
       ! returned from the species database.  If not, there's an error.
       IF ( N_Hg0_CATS == N_Hg2_CATS .and. N_Hg0_CATS == N_HgP_CATS ) THEN
          State_Chm%N_Hg_CATS = N_Hg0_CATS
       ELSE
          RC = GC_FAILURE
          PRINT*, '### Inconsistent number of Hg categories!'
          RETURN
       ENDIF

       ! Index array: Hg0 species # <--> Hg0 category #
       ALLOCATE( State_Chm%Hg0_Id_List( State_Chm%N_Hg_CATS ), STAT=RC )
       IF ( RC /= GC_SUCCESS ) RETURN
       State_Chm%Hg0_Id_List = 0

       ! Index array: Hg2 species # <--> Hg0 category #
       ALLOCATE( State_Chm%Hg2_Id_List( State_Chm%N_Hg_CATS ), STAT=RC )
       IF ( RC /= GC_SUCCESS ) RETURN
       State_Chm%Hg2_Id_List = 0

       ! Index array: HgP species # <--> Hg0 category #
       ALLOCATE( State_Chm%HgP_Id_List( State_Chm%N_Hg_CATS ), STAT=RC )
       IF ( RC /= GC_SUCCESS ) RETURN
       State_Chm%HgP_Id_List = 0

       ! Hg category names
       ALLOCATE( State_Chm%Hg_Cat_Name( State_Chm%N_Hg_CATS ), STAT=RC )
       IF ( RC /= GC_SUCCESS ) RETURN
       State_Chm%Hg_Cat_Name = ''

       ! Loop over all species
       DO N = 1, State_Chm%nSpecies

          ! Point to Species Database entry for Hg species N
          ThisSpc => State_Chm%SpcData(N)%Info
          
          ! Populate the Hg0 index array
          IF ( ThisSpc%Is_Hg0 ) THEN
             State_Chm%Hg0_Id_List(ThisSpc%Hg_Cat) = ThisSpc%ModelId
          ENDIF

          ! Populate the Hg2 index array
          IF ( ThisSpc%Is_Hg2 ) THEN
             State_Chm%Hg2_Id_List(ThisSpc%Hg_Cat) = ThisSpc%ModelId
          ENDIF

          ! Populate the HgP index array
          IF ( ThisSpc%Is_HgP ) THEN
             State_Chm%HgP_Id_List(ThisSpc%Hg_Cat) = ThisSpc%ModelId
          ENDIF

          ! Free pointer
          ThisSpc => NULL()
       ENDDO

       ! Loop over Hg categories (except the first
       DO C = 2, State_Chm%N_Hg_CATS

          ! Hg0 tracer number corresponding to this category
          N                        =  State_Chm%Hg0_Id_List(C)

          ! The category name (e.g. "_can") follows the "Hg0"
          ThisSpc                  => State_Chm%SpcData(N)%Info
          State_Chm%Hg_Cat_Name(C) =  ThisSpc%Name(4:7)
          ThisSpc                  => NULL()
       ENDDO
       
    ENDIF
   
    SpcDataLocal => State_Chm%SpcData

    ! Free pointer for safety's sake
    ThisSpc => NULL()

    ! Echo output
    IF ( am_I_Root ) THEN
       print*, REPEAT( '#', 79 )
    ENDIF 

    ! Format statement
100 FORMAT( I3, 1x, A10, 3x, F7.2 )
110 FORMAT( 5x, '===> ', f4.1, 1x, A6  )
120 FORMAT( 5x, '---> ', f4.1, 1x, A4  )

  END SUBROUTINE Init_State_Chm
!EOC
!------------------------------------------------------------------------------
!                  GEOS-Chem Global Chemical Transport Model                  !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: cleanup_state_chm
!
! !DESCRIPTION: Routine CLEANUP\_STATE\_CHM deallocates all fields 
!  of the chemistry state object.
!\\
!\\
! !INTERFACE:
!
  SUBROUTINE Cleanup_State_Chm( am_I_Root, State_Chm, RC )
!
! !USES:
!
    USE ErrCode_Mod 
    USE Species_Database_Mod, ONLY : Cleanup_Species_Database
!
! !INPUT PARAMETERS:
! 
    LOGICAL,        INTENT(IN)    :: am_I_Root    ! Is this the root CPU?
!
! !INPUT/OUTPUT PARAMETERS:
!
    TYPE(ChmState), INTENT(INOUT) :: State_Chm    ! Chemistry State object
!
! !OUTPUT PARAMETERS:
!
    INTEGER,        INTENT(OUT)   :: RC           ! Return code
!
! !REMARKS:
!  For now the am_I_Root and RC arguments are not used.  We include these
!  for consistency and also to facilitate future expansion. (bmy, 10/16/12)
!
! !REVISION HISTORY: 
!  15 Oct 2012 - R. Yantosca - Initial version
!  26 Oct 2012 - R. Yantosca - Now deallocate Strat_P, Strat_k fields
!  26 Feb 2013 - M. Long     - Now deallocate State_Chm%DEPSAV
!  11 Dec 2014 - R. Yantosca - Remove TRAC_TEND and DEPSAV fields
!  28 Aug 2015 - R. Yantosca - Remove stratospheric chemistry fields; 
!                              these are all now read in via HEMCO
!  28 Aug 2015 - R. Yantosca - Also initialize the species database object
!EOP
!------------------------------------------------------------------------------
!BOC

    ! Assume success
    RC = GC_SUCCESS

    !======================================================================
    ! Deallocate fields
    !=======================================================================
    IF ( ASSOCIATED( State_Chm%Map_Advect) ) THEN
       DEALLOCATE( State_Chm%Map_Advect )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Map_DryDep ) ) THEN
       DEALLOCATE( State_Chm%Map_DryDep )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Map_KppSpc ) ) THEN
       DEALLOCATE( State_Chm%Map_KppSpc )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Map_WetDep ) ) THEN
       DEALLOCATE( State_Chm%Map_WetDep )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Spec_Id  ) ) THEN
       DEALLOCATE( State_Chm%Spec_Id )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Spec_Name ) ) THEN
       DEALLOCATE( State_Chm%Spec_Name  )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Species ) ) THEN
       DEALLOCATE( State_Chm%Species )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Hg_Cat_Name ) ) THEN
       DEALLOCATE( State_Chm%Hg_Cat_Name )
    ENDIF

    IF ( ASSOCIATED( State_Chm%Hg0_Id_List ) ) THEN
       DEALLOCATE( State_Chm%Hg0_Id_List ) 
    ENDIF

    IF ( ASSOCIATED( State_Chm%Hg2_Id_List ) ) THEN
       DEALLOCATE( State_Chm%Hg2_Id_List )
    ENDIF

    IF ( ASSOCIATED( State_Chm%HgP_Id_List ) ) THEN
       DEALLOCATE( State_Chm%HgP_Id_List )
    ENDIF

    IF ( ASSOCIATED( State_Chm%AeroArea ) ) THEN
       DEALLOCATE( State_Chm%AeroArea   )
    ENDIF

    IF ( ASSOCIATED( State_Chm%AeroRadi ) ) THEN
       DEALLOCATE( State_Chm%AeroRadi )
    ENDIF

    IF ( ASSOCIATED(State_Chm%WetAeroArea) ) THEN
       DEALLOCATE(State_Chm%WetAeroArea)
    ENDIF

    IF ( ASSOCIATED(State_Chm%WetAeroRadi) ) THEN
       DEALLOCATE(State_Chm%WetAeroRadi)
    ENDIF

    IF ( ASSOCIATED(State_Chm%pHCloud) ) THEN
       DEALLOCATE(State_Chm%pHCloud)
    ENDIF

    IF ( ASSOCIATED(State_Chm%SSAlk) ) THEN
       DEALLOCATE(State_Chm%SSAlk)
    ENDIF

    IF ( ASSOCIATED( State_Chm%STATE_PSC ) ) THEN
       DEALLOCATE(State_Chm%STATE_PSC  )
    ENDIF
       
    IF ( ASSOCIATED( State_Chm%KHETI_SLA ) ) THEN
       DEALLOCATE( State_Chm%KHETI_SLA  )
    ENDIF

    ! Deallocate the species database object field
    CALL Cleanup_Species_Database( am_I_Root, State_Chm%SpcData, RC )

  END SUBROUTINE Cleanup_State_Chm
!EOC
END MODULE State_Chm_Mod
