##################
#  WIP Report
##################

library(ggplot2)
library(alluvial)
library(tidyr)
library(data.table) #sort data frame

donations <- read.csv(file = "C:\\Users\\aaust\\OneDrive\\Documents\\Syracuse Classes\\IST 719\\Project\\sports-political-donations.csv"
                      , header = T, stringsAsFactors = FALSE)

####################
# Data Cleaning
####################

# Clean amount & year column and convert to number
donations$Amount <- as.numeric(gsub("[[:punct:]]",'',donations$Amount))

# Shorten "Bipartisan but mostly republican/democrat"
donations$Party <- gsub("Bipartisan, but mostly Democratic", "Democrat", donations$Party)
donations$Party <- gsub("Bipartisan, but mostly Republican", "Republican", donations$Party)
# Since Independent & N/A are such small portions of data set, and we're mostly concerned with
# Republican & Democrat donations, make these "Bipartisan"
donations$Party <- gsub("N/A", "Bipartisan", donations$Party)
donations$Party <- gsub("Independent", "Bipartisan", donations$Party)


## Unlist leagues + teams
d.leagues <- separate_rows(donations, League, sep=",\\s+")
d.teams <- separate_rows(donations, Team, sep=",\\s+")


####################
# Alluvial Plot
####################

alluv.df <- aggregate(d.leagues$Amount, list(d.leagues$League, d.leagues$Party), sum)
colnames(alluv.df) <- c("League", "Party", "Donation.Amount")

# Adding colors
my.cols <- rep("blue", nrow(alluv.df))
my.cols[alluv.df$Party == "Republican"] <- "red"
my.cols[alluv.df$Party == "Bipartisan"] <- "gray"
alluvial(alluv.df[ , 1:2], freq = alluv.df$Donation.Amount, col = my.cols, alpha = 0.4)

ggplot(data = alluv.df, aes(axis1 = League, axis2 = Party, y = Donation.Amount)) +
  geom_alluvium(aes(fill = Donation.Amount)) +
  geom_stratum() +
  geom_text(stat = "stratum", aes(label = after_stat(stratum))) +
  scale_x_discrete(limits = c("League", "Party"), expand = c(0.15, 0.05)) +
  theme_void()



####################
# Top Donors
####################

# Top donors
donations.tmp <- aggregate(donations$Amount, list(donations$Owner, donations$Party), sum)
colnames(donations.tmp) <- c("Owner", "Party", "Donation.Amount")
donations.tmp <- donations.tmp[donations.tmp$Donation.Amount > 1000000, ]

# Color bars based on party
my.cols <- rep("blue", nrow(donations.tmp))
my.cols[donations.tmp$Party == "Republican"] <- "red"
donations.tmp$PartyCol <- my.cols

ggplot(donations.tmp) + aes(x = reorder(Owner, Donation.Amount), y = Donation.Amount) +
  geom_bar(stat = "identity", fill = my.cols) + coord_flip()

# Only Charles Johnson Donations
donations.CJ <- donations[donations$Owner == "Charles Johnson", ]
aggregate(donations.CJ$Amount, list(donations.CJ$Recipient), sum)


####################
# Single Variable
####################

# Distribution Of Donations
my.cols <- rep("blue", nrow(donations))
my.cols[donations$Party == "Republican"] <- "red"
my.cols[donations$Party == "Bipartisan"] <- "gray"
plot(donations$Amount, ylab = "Donation Amount ($)", pch = 16, col = my.cols)

# Distribution of Party (1 dimension)
ggplot(data = donations, aes(x = Party)) + geom_bar() + ylab("Frequency")

# Distribution of year
ggplot(data = donations, aes(x = Election.Year)) + geom_bar() + ylab("Frequency")

# Quick summary stations for annotations
aggregate(donations$Amount, list(donations$Party), sum)
aggregate(donations$Amount, list(donations$Party), mean)
mean(donations$Amount)


#############
# Teams
#############

tmp <- as.data.frame.matrix(table(d.teams$Team, d.teams$Party))
t <- as.data.frame(sort(unique(d.teams$Team)))
colnames(t) <- c("Team")
t$Party <- tmp$Republican - tmp$Democrat
tmp <- aggregate(d.teams$Amount, list(d.teams$Team), sum)
t$Amount <- tmp$x
t

ggplot(t) + aes(x = Party, y = Amount) + geom_point(color = ifelse(t$Party > 0, "red", "blue")) +
  geom_text(aes(label=ifelse(Party > 50 | Party < -40 | Amount > 2000000,as.character(Team),'')))

