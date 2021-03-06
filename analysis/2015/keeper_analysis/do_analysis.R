setwd("/home/john/stats_corner/2015/keeper_analysis/")

keepers <- read.csv("keepers.csv", header = TRUE, stringsAsFactors = FALSE)
keepers <- keepers %>%
    mutate(est_cost2 = round(est_cost),
           adj_value2 = round(adj_value),
            savings = est_cost2 - adj_value2)
colnames(keepers)
# Most valuable keepers ever #
keepers %>% arrange(desc(savings)) %>% select(c(1,2,3,4,5,10,11,9)) %>% slice(1:10)

# Least valuable keepers ever #
keepers %>% arrange(savings) %>% select(c(1,2,3,4,5,8,9)) %>% slice(1:10)

# Least value  #
keepers %>%
    group_by(player) %>%
    summarise(total_savings = sum(savings),
              times_kept = n(),
              dif_owners = n_distinct(owner)) %>%
    arrange(desc(total_savings)) %>%
    slice(1:10)

# Least valuable keepers #
keepers %>%
    group_by(player) %>%
    summarise(total_savings = sum(savings),
              times_kept = n(),
              dif_owners = n_distinct(owner)) %>%
    arrange(total_savings) %>%
    slice(1:10)

# Owner rankings
keepers %>%
    group_by(owner) %>%
    summarise(total_savings = sum(savings)) %>%
    arrange(desc(total_savings))



### Fold in prop wins ###
library(googlesheets)
library(dplyr)
library(ggplot2)
library(reshape2)
sheet <- gs_title("Bad Newz Archives")


owner <- sheet %>% gs_read(ws = "Owner-Team Name")
games <- sheet %>% gs_read(ws = "Regular Season Games")

owner_game <- left_join(games,owner,by=c("year","team"))

## Arrange data and create win, loss and tie variables
data <- arrange(owner_game,game_id,points)
data$W <- rep(0,dim(data)[1])
data$L <- rep(0,dim(data)[1])
data$T <- rep(0,dim(data)[1])
data$PA <- rep(0,dim(data)[1])
data$result <- rep(" ",dim(data)[1])

### Loop to determine winners, and points against
for(i in seq(from=1,to=dim(data)[1],by=2)){
    
    data$PA[i]   <- data$points[i+1]
    data$PA[i+1] <- data$points[i]
    
    data$Opponent[i] <- data$owner[i+1]
    data$Opponent[i+1] <- data$owner[i]
    
    if(data$points[i] < data$points[i+1]){
        data$L[i] <- 1
        data$W[i+1] <- 1
        data$result[i] <- "L"
        data$result[i+1] <- "W"
        
    }
    if(data$points[i] == data$points[i+1]){
        data$T[i] <- 1
        data$T[i+1] <- 1
        data$result[i] <- "T"
        data$result[i+1] <- "T"
    }
}


data <- data %>%
    arrange(year,week,desc(points)) %>%
    group_by(year,week) %>%
    mutate(rk = rank(points,ties.method="min")) 

# Now to calculate and add up proportional wins
data$pw<- ifelse(data$year==2009,(data$rk-1)/9,(data$rk-1)/11)
data <- ungroup(data)  %>% arrange(desc(points))
#select(data, year, week, owner, points, Opponent)
#data <- filter(data, year != 2015)

## season pw totals ##
pw_totals <- data %>%
    group_by(owner,year) %>%
    summarise(total_pw = sum(pw)) %>%
    ungroup() %>%
    group_by(year) %>%
    mutate(pw_rank = rank(-total_pw,ties.method="min"))

pw_totals$owner <- ifelse(pw_totals$owner == 'Skrzyszewski',
                          'Skrzyskewski',
                          pw_totals$owner)

keeper_pw <- inner_join(keepers,pw_totals, by = c("owner","year"))
#anti_join(keepers,pw_totals,by=c("owner","year"))

# effective draft cash all time #
a<-keepers %>%
    group_by(owner,year) %>%
    summarise(total_savings = sum(savings),
              effective_draft_cash = 300 + total_savings) %>%
    ungroup() %>%
    arrange(desc(effective_draft_cash)) %>%
    slice(1:10) %>% 
    left_join(.,pw_totals,by = c("owner","year"))
a$pw_rank <- ifelse(a$year == 2015,
                    NA,
                    a$pw_rank)
kable(a)
# least effective draft cash
b<- keepers %>%
    group_by(owner,year) %>%
    summarise(total_savings = sum(savings),
              effective_draft_cash = 300 + total_savings) %>%
    ungroup() %>%
    arrange(effective_draft_cash) %>%
    slice(1:10) %>%
    left_join(.,pw_totals,by = c("owner","year"))
b$pw_rank <- ifelse(b$year == 2015,
                    NA,
                    b$pw_rank)

with(filter(a, year != 2015),cor(effective_draft_cash,pw_rank))
with(filter(a, year != 2015), plot(effective_draft_cash,pw_rank))

## This year's rankings
c <- keepers %>%
    filter(year == 2015) %>%
    group_by(owner)%>%
    summarise(total_savings = sum(savings),
              effective_draft_cash = 300 + total_savings) %>%
    ungroup() %>%
    arrange(desc(effective_draft_cash))
c
