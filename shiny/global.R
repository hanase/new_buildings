library(shiny)
library(shinythemes)
library(leaflet)
library(dplyr)
library(tidyverse)
#library(DT)
library(data.table)

base.ind.dir <- "/media/modelsrv8d/opusgit/urbansim_data/data/psrc_parcel/runs"
#base.ind.dir <- "/Volumes/d$/opusgit/urbansim_data/data/psrc_parcel/runs"
#base.ind.dir <- "/Users/hana/d$/opusgit/urbansim_data/data/psrc_parcel/runs"
#base.ind.dir <- "~/tmpind"
             

wrkdir <- '/home/shiny/apps/' # shiny path
#wrkdir <- '/Users/hana/R/shinyserver/'
#wrkdir <- '/Users/hana/psrc/R/shinyserver'
# wrkdir <- 'C:/Users/CLam/Desktop/'

data <- 'parcel-viewer/data'
bld.data <- "new_buildings/data"

parcel.main <- 'parcels2014.rds'
parcel.att <- 'parcels_for_viewer.rds'

parcels <- data.table(readRDS(file.path(wrkdir, data, parcel.main)))
setkey(parcels, parcel_id)
attr <- data.table(readRDS(file.path(wrkdir, data, parcel.att)))
setkey(attr, parcel_id)

parcels <- attr %>% merge(parcels, all.x=TRUE)
parcels <- parcels[,-c(20:35)] # remove a few attributes to reduce size
parcels[, c("max_dua", "max_far", "building_sqft") := NULL] # remove these columns as they'll come from the plan_types table

rm(attr)

building_types <- read.csv(file.path(wrkdir, bld.data, "building_types.csv"), stringsAsFactors = FALSE)[,c("building_type_id", "building_type_name")]
ordered_building_type_names <- c("single_family_residential", "condo_residential", "multi_family_residential", 
                                 "commercial", "office", "industrial", "warehousing", "tcu")
building_types_selection <- subset(building_types, building_type_name %in% ordered_building_type_names)
rownames(building_types_selection) <- building_types_selection$building_type_name
building_types_selection <- building_types_selection[ordered_building_type_names,"building_type_id", drop=FALSE]
building_types <- data.table(building_types)
setkey(building_types, building_type_id)
color.attributes <- c("year"="year_built", "bt"="building_type_id", 
                      "sizeres"="residential_units.x", "sizenonres"="non_residential_sqft")

########
# Create a dataset of plan types from costraints table
########
constr <- fread(file.path(wrkdir, bld.data, "development_constraints.csv"))
setkey(constr, plan_type_id)

# Create tables of residential and non-res constraints that 
# count the number of constraints and get their minimum and maximum
resconstr <- constr[constraint_type == "units_per_acre", 
                    .(N_res_con=.N, max_dua = max(maximum), min_dua=min(minimum)),
                    by= plan_type_id]

nonresconstr <- constr[constraint_type == "far", 
                       .(N_nonres_con=.N, max_far = max(maximum), min_far=min(minimum)),
                       by= plan_type_id]

# Outer join of the two tables by pan_type_id
plantypes <- merge(resconstr, nonresconstr, all = TRUE)
# replace NAs with 0s
plantypes[is.na(N_res_con), N_res_con:=0]
plantypes[is.na(N_nonres_con), N_nonres_con:=0]

# Merge plan types with parcels table
setkey(parcels, plan_type_id)
setkey(plantypes, plan_type_id)

parcels <- merge(parcels, plantypes, all.x = TRUE)
setkey(parcels, parcel_id)
