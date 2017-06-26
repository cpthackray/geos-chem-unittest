#!/bin/bash

# runSettings.sh: Update select settings in GCHP *.rc files
#
# Usage: ./runSettings.sh
#
# NOTE: This script is under development. Add functionality as needed
# and see ideas for the future at the bottom of the script (ewl, 1/19/16)

##########################
####  Configurables   ####
##########################

#### COMPUTE RESOURCES
NUM_NODES=1
NUM_CORES_PER_NODE=6
NY=6                  # NY must be an integer and a multiple of 6
NX=1                  # NX*NY must equal total number of cores
                      # Choose NX and NY to optimize NX x NY/6 squareness
                      # within contraint of total # of CPUs
                      # e.g., (NX=2,NY=12) if 24 cores, (NX=4,NY=12) if 48

#### INPUT MET RESOLUTION
INPUT_MET_RES=2x25    # 4x5, 2x25, etc (warning: not yet implemented)

### INTERNAL CUBED-SPHERE RESOLUTION
CUBE_SPHERE_RES=24    # 24~4x5, 48~2x2.5, etc.

#### SIMULATION TIMES
Start_Time="20130701 000000"
End_Time="20130701 010000"
Duration="00000000 010000"

#### OUTPUT
cs_frequency="010000"
cs_duration="010000"
cs_mode="'time-averaged'"
ll_frequency="010000"
ll_duration="010000"
ll_mode="'time-averaged'"

#### TURN COMPONENTS ON/OFF
Turn_on_Chemistry=T
Turn_on_emissions=T
Turn_on_Dry_Deposition=T
Turn_on_Wet_Deposition=T
Turn_on_Transport=T
Turn_on_Cloud_Conv=T
Turn_on_PBL_Mixing=T

#### DEBUG OPTIONS
MAPL_DEBUG_LEVEL=0   # 0 is none, output increases with higher values (to 20)
#GC_ND70="0 all"     # requires special handling; omit for now

#### TIMESTEPS
Transport_Timestep_min=10
Convect_Timestep_min=10
Emissions_Timestep_min=20
Chemistry_Timestep_min=20

#### GENERAL
Use_variable_tropopause=T
Type_of_simulation=3

#### PBL MIXING
Use_nonlocal_PBL=T

#### EMISSIONS
HEMCO_Input_file=HEMCO_Config.rc
ppt_MBL_BRO_Sim=F
Use_CH4_emissions=F
#sfc_BC_CH4=T  # these need special handling since duplicate text in input.geos
#sfc_BC_OCS=T  # omit for now
#sfc_BC_CFCs=T
#sfc_BC_Cl_species=T
#sfc_BC_Br_species=F
#sfc_BC_N2O=T
initial_MR_strat_H2O=T
CFC_emission_year=0

#### AEROSOLS
Online_SULFATE_AEROSOLS=T
Online_CRYST_AQ_AEROSOLS=F
Online_CARBON_AEROSOLS=T
se_Brown_Carbon=F
Online_2dy_ORG_AEROSOLS=T
Semivolatile_POA=F
Online_DUST_AEROSOLS=T
Acidic_uptake=F
Online_SEASALT_AEROSOLS=T
#SALA_radius_bin_um="0.01 0.5" # requires special handling; omit for now
#SALC_radius_bin_um="0.5  8.0" # requires special handling; omit for now
MARINE_ORG_AEROSOLS=F
Online_dicarb_chem=F
Settle_strat_aerosols=T
Online_PSC_AEROSOLS=T
Allow_homogeneous_NAT=F
NAT_supercooling_req_K=3.0
Ice_supersaturation_req=1.2
Perform_PSC_het_chem=T
Calc_strat_aero_OD=T

#### CHEMISTRY
Use_linear_strat_chem=T
Use_Linoz_for_O3=T
Use_UCX_strat_chem=T
Active_strat_H2O=T
Online_O3_for_FAST_JX=T
Gamma_HO2=0.2

##################################
####   End of Configurables   ####
##################################

#############################################
###   Extract Info from HEMCO_Config.rc   ###
#############################################

# placeholder

################################################################
###   Give Warnings and/or Stop if Settings Not Compatible   ###
################################################################
# Check that timesteps make sense (emiss=chem, conv=transport)
# Give relevant warnings about timesteps in input.geos vs. GCHP (temporary)
# Give warnings about CS resolution and timestep compatibility
# Issue any other warnings/errors regarding input.geos and/or run settings
# check that the transport settins are consistent

#### Convert timesteps to seconds
DYN_DT_S=$((${Transport_Timestep_min}*60))
CHEM_DT_S=$((${Chemistry_Timestep_min}*60))

#### Check that emissions and chem timesteps are the same
if [[ ${Convect_Timestep_min} -ne ${Transport_Timestep_min} ]]; then
    echo "ERROR: convection timestep must be equal to transport timestep"
    exit 1
fi

#### Check that dynamic and convection timesteps are the same
if [[ ${Chemistry_Timestep_min} -ne ${Emissions_Timestep_min} ]]; then
    echo "ERROR: chemistry timestep must be equal to emissions timestep"
    exit 1
fi

#### Check that chem timestep is >= dynamic timestep
if [[ ${Chemistry_Timestep_min} -lt ${Transport_Timestep_min} ]]; then
    echo "ERROR: chemistry timestep must be >= dynamic timestep"
    exit 1
fi

#### Check that NX*NY is equal to number of cores
num_cores=$((  ))
if (( $NX*$NY != $NUM_NODES*$NUM_CORES_PER_NODE )); then
    echo "ERROR: NX*NY must equal number of nodes times cores per node"
    exit 1    
fi

#### Check that NY is divisible by 6
if (( $NY%6 != 0 )); then
    echo "ERROR: NY must be an integer divisible by 6"
    exit 1    
fi

#### Check if domains are square enough (NOTE: approx using integer division)
domain_ratio1=$(( $NX*6/$NY )) 
domain_ratio2=$(( $NY/$NX/6 ))
if [[ ${domain_ratio1} -ge 3 || ${domain_ratio2} -ge 3 ]] ; then
    echo "ERROR: Change NX and NY such that NX x NY/6 is more square (side ratio < 3)"
    exit 1
fi

###############################
###   Update .rc Files   ###
###############################

#### Save backups of originals
if [ ! -f GCHP.rc.orig ]; then
    cp GCHP.rc GCHP.rc.orig
fi
if [ ! -f CAP.rc.orig ]; then
    cp CAP.rc CAP.rc.orig
fi
if [ ! -f fvcore_layout.rc.orig ]; then
    cp fvcore_layout.rc fvcore_layout.rc.orig
fi
if [ ! -f input.geos.orig ]; then
    cp input.geos input.geos.orig
fi
if [ ! -f HISTORY.rc.orig ]; then
    cp HISTORY.rc HISTORY.rc.orig
fi

#### Define function to replace values in .rc files
replace_val() {
    KEY=$1
    VALUE=$2
    FILE=$3
    printf '%-30s : %-20s %-20s\n' "${KEY}" "${VALUE}" "${FILE}"
    #echo "      ${KEY}    :    ${VALUE}     (${FILE})"

    # replace value in line starting with 'whitespace + key + whitespace + : +
    # whitespace + value' where whitespace is variable length including none
    sed "s|^\([\t ]*${KEY}[\t ]*:[\t ]*\).*|\1${VALUE}|" ${FILE} > tmp
    mv tmp ${FILE}
}

#### Define transport string for GCHP.rc
if [[ ${Turn_on_Transport} == "T" ]]; then
    ADVCORE_ADVECTION=1
elif [[ ${Turn_on_Transport} == "F" ]]; then
    ADVCORE_ADVECTION=0
else
    echo "ERROR: Incorrect transport setting"
    exit 1
fi

#### Set # nodes and # cores
echo "Compute resources:"
replace_val NX            "${NX}" GCHP.rc
replace_val NY            "${NY}" GCHP.rc
replace_val CoresPerNode  "${NUM_CORES_PER_NODE}" HISTORY.rc

####  set cubed-sphere resolution
echo " "
echo "Cubed-sphere resolution:"
CS_RES_TIMES_SIX=$((CUBE_SPHERE_RES*6)) # Is there a better term for this?
replace_val IM            "${CUBE_SPHERE_RES}"  GCHP.rc
replace_val JM            "${CS_RES_TIMES_SIX}" GCHP.rc
replace_val npx           "${CUBE_SPHERE_RES}"  fvcore_layout.rc
replace_val npy           "${CUBE_SPHERE_RES}"  fvcore_layout.rc
replace_val GRIDNAME "PE${CUBE_SPHERE_RES}x${CS_RES_TIMES_SIX}-CF" GCHP.rc

#### Set simulation start and end datetimes based on input.geos
echo " "
echo "Simulation start, end, duration:"
replace_val BEG_DATE      "${Start_Time}" CAP.rc
replace_val END_DATE      "${End_Time}"   CAP.rc
replace_val JOB_SGMT      "${Duration}"   CAP.rc

#### Set output frequency, duration, and mode
echo " "
echo "Output:"
replace_val center.frequency "${cs_frequency}"  HISTORY.rc
replace_val center.duration  "${cs_duration}"   HISTORY.rc
replace_val center.mode      "${cs_mode}"       HISTORY.rc
replace_val regrid.frequency "${ll_frequency}"  HISTORY.rc
replace_val regrid.duration  "${ll_duration}"   HISTORY.rc
replace_val regrid.mode      "${ll_mode}"       HISTORY.rc

#### Set timesteps based on input.geos
echo " "
echo "Timesteps:"
replace_val HEARTBEAT_DT  "${DYN_DT_S}"  GCHP.rc
replace_val SOLAR_DT      "${DYN_DT_S}"  GCHP.rc
replace_val IRRAD_DT      "${DYN_DT_S}"  GCHP.rc
replace_val RUN_DT        "${DYN_DT_S}"  GCHP.rc
replace_val GIGCchem_DT   "${CHEM_DT_S}" GCHP.rc
replace_val DYNAMICS_DT   "${DYN_DT_S}"  GCHP.rc
replace_val HEARTBEAT_DT  "${DYN_DT_S}"  CAP.rc
replace_val dt            "${DYN_DT_S}"  fvcore_layout.rc

#### Set debug level
echo " "
echo "MAPL Debug Level:"
replace_val DEBUG_LEVEL "${MAPL_DEBUG_LEVEL}" CAP.rc

#### Set advection on/off based on input.geos
echo " "
echo "Advection on/off:"
replace_val AdvCore_Advection "${ADVCORE_ADVECTION}" GCHP.rc

##### Set input.geos
echo " "
echo "General:"
replace_val "Use variable tropopause?" ${Use_variable_tropopause} input.geos
replace_val "Type of simulation"       ${Type_of_simulation}      input.geos
echo " "
echo "Components on/off:"
replace_val "Turn on Chemistry?"        ${Turn_on_Chemistry}        input.geos
replace_val "Turn on emissions?"	${Turn_on_emissions}      input.geos
replace_val "Turn on Transport"	        ${Turn_on_Transport}      input.geos
replace_val "Turn on Cloud Conv?"	${Turn_on_Cloud_Conv}     input.geos
replace_val "Turn on PBL Mixing?"	${Turn_on_PBL_Mixing}     input.geos
replace_val "Turn on Dry Deposition?"   ${Turn_on_Dry_Deposition}   input.geos
replace_val "Turn on Wet Deposition?"   ${Turn_on_Wet_Deposition}   input.geos
echo " "
echo "Timesteps:"
replace_val "Chemistry Timestep [min]"	${Chemistry_Timestep_min}   input.geos
replace_val "Emiss Timestep [min]"	${Emissions_Timestep_min} input.geos
replace_val "Transport Timestep [min]"  ${Transport_Timestep_min} input.geos
replace_val "Convect Timestep [min]"    ${Convect_Timestep_min}   input.geos
echo " "
echo "Mixing:"
replace_val "=> Use non-local PBL?"	${Use_nonlocal_PBL}       input.geos
echo " "
echo "Emissions:"
replace_val "HEMCO Input file"	        ${HEMCO_Input_file}       input.geos
replace_val "=> 1ppt MBL BRO Sim.?"	${ppt_MBL_BRO_Sim}        input.geos
replace_val "=> strat. H2O?"	      	${initial_MR_strat_H2O}   input.geos
replace_val "=> CFC emission year"      ${CFC_emission_year}        input.geos
echo " "
echo "Aerosols:"
replace_val "Online SULFATE AEROSOLS"   ${Online_SULFATE_AEROSOLS}  input.geos
replace_val "Online CRYST/AQ AEROSOLS"  ${Online_CRYST_AQ_AEROSOLS} input.geos
replace_val "Online CARBON  AEROSOLS" 	${Online_CARBON_AEROSOLS}   input.geos
replace_val "=> Use Brown Carbon?"      ${se_Brown_Carbon}          input.geos
replace_val "Online 2dy ORG AEROSOLS" 	${Online_2dy_ORG_AEROSOLS}  input.geos
replace_val "=> Semivolatile POA?"      ${Semivolatile_POA}         input.geos
replace_val "Online DUST    AEROSOLS" 	${Online_DUST_AEROSOLS}     input.geos
replace_val "=> Acidic uptake ?"        ${Acidic_uptake}            input.geos
replace_val "Online SEASALT AEROSOLS"   ${Online_SEASALT_AEROSOLS}  input.geos
#replace_val "=> SALA radius bin [um]"   ${SALA_radius_bin_um}       input.geos
#replace_val "=> SALC radius bin [um]"   ${SALC_radius_bin_um}       input.geos
replace_val "=> MARINE ORG AEROSOLS"    ${MARINE_ORG_AEROSOLS}      input.geos
replace_val "Online dicarb. chem."      ${Online_dicarb_chem}       input.geos
replace_val "Settle strat. aerosols"  	${Settle_strat_aerosols}    input.geos
replace_val "Online PSC AEROSOLS"       ${Online_PSC_AEROSOLS}      input.geos
replace_val "Allow homogeneous NAT?"  	${Allow_homogeneous_NAT}    input.geos 
replace_val "NAT supercooling req.(K)"  ${NAT_supercooling_req_K}   input.geos
replace_val "Ice supersaturation req."  ${Ice_supersaturation_req}  input.geos
replace_val "Perform PSC het. chem.?"   ${Perform_PSC_het_chem}     input.geos
replace_val "Calc. strat. aero. OD?"    ${Calc_strat_aero_OD}       input.geos
echo " "
echo "Chemistry:"
replace_val "Use linear. strat. chem?"	${Use_linear_strat_chem}    input.geos
replace_val "=> Use Linoz for O3?"      ${Use_Linoz_for_O3}         input.geos
replace_val "Use UCX strat. chem?"    	${Use_UCX_strat_chem}       input.geos
replace_val "Active strat. H2O?"      	${Active_strat_H2O}         input.geos
replace_val "Online O3 for FAST-JX?"    ${Online_O3_for_FAST_JX}    input.geos
replace_val "Gamma HO2"                 ${Gamma_HO2}                input.geos 
	    
################################################
###   Print Run Settings to runSettings.log  ###
################################################

# placeholder


# Additional notes:
#
# Setting values in input.geos from this file:
#    Use variable tropopause?: T
#    Type of simulation      : 3

