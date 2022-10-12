# SETUP --------------------------------------------------
root <- getwd()
while(basename(root) != "ags_capital_vs_output") {
  root <- dirname(root)
}

# Load the packages we need 
packages <- c("tidyverse", "cowplot", "gridExtra", "pBrackets")
invisible(lapply(packages, library, character.only = T))


## CONSTRUCT INDIVIDUAL BID CURVES ----------

## parameters
b_nonwind = -100
m_nonwind = .5
windcap = 200
delta = .25
windcap <- 200
subsidy <- 50
md_mid <- 25 
md_hi <- 75

mc_nonwind <- seq(1:500) %>%
  as.data.frame() %>%
  mutate(d = as.numeric(row_number()),
         mc = b_nonwind + m_nonwind*d)

mc_private <- seq(1:windcap) %>%
  as.data.frame() %>%
  mutate(mc = 0, 
         bid = mc,
         soc_mc0 = mc,
         soc_mc_mid = mc,
         soc_mc_hi = mc) %>%
  bind_rows(mc_nonwind %>%
              mutate(bid = mc,
                     soc_mc0 = mc,
                     soc_mc_mid = mc + md_mid,
                     soc_mc_hi = mc + md_hi)) %>%
  arrange(bid) %>%
  mutate(d = row_number()) 

mc_private_ptc <- seq(1:(windcap*(1+delta))) %>%
  as.data.frame() %>%
  mutate(mc = 0, 
         bid = mc - subsidy,
         soc_mc0_ptc = mc,
         soc_mc_mid_ptc = mc,
         soc_mc_hi_ptc = mc) %>%
  bind_rows(mc_nonwind %>%
              mutate(bid = mc,
                     soc_mc0_ptc = mc,
                     soc_mc_mid_ptc = mc + md_mid,
                     soc_mc_hi_ptc = mc + md_hi)) %>%
  arrange(bid) %>%
  mutate(d = row_number()) 

mc_private_ptc_dispatch <- seq(1:(windcap)) %>%
  as.data.frame() %>%
  mutate(mc = 0, 
         bid = mc - subsidy,
         soc_mc0_ptc_di = mc,
         soc_mc_mid_ptc_di = mc,
         soc_mc_hi_ptc_di = mc) %>%
  bind_rows(mc_nonwind %>%
              mutate(bid = mc,
                     soc_mc0_ptc_di = mc,
                     soc_mc_mid_ptc_di = mc + md_mid,
                     soc_mc_hi_ptc_di = mc + md_hi)) %>%
  arrange(bid) %>%
  mutate(d = row_number()) 


wide_data <-
  mc_private %>%
  left_join(mc_private_ptc , by = c("d")) %>%
  left_join(mc_private_ptc_dispatch , by = c("d")) %>%
  mutate(tc0 = cumsum(soc_mc0),
          tc0_ptc = cumsum(soc_mc0_ptc),
          net0 = tc0 - tc0_ptc,
          tc0_ptc_di = cumsum(soc_mc0_ptc_di),
          net0_di = tc0 - tc0_ptc_di,
         tc_mid = cumsum(soc_mc_mid),
          tc_mid_ptc = cumsum(soc_mc_mid_ptc),
          net_mid = tc_mid - tc_mid_ptc,
          tc_mid_ptc_di = cumsum(soc_mc_mid_ptc_di),
          net_mid_di = tc_mid - tc_mid_ptc_di,
         tc_hi = cumsum(soc_mc_hi),
          tc_hi_ptc = cumsum(soc_mc_hi_ptc),
          net_hi = tc_hi - tc_hi_ptc,
          tc_hi_ptc_di = cumsum(soc_mc_hi_ptc_di),
          net_hi_di = tc_hi - tc_hi_ptc_di)


## PLOT BID CURVES FOR BACKGROUND ----------

( p_bids <- mc_nonwind %>% rename(bid_nonwind = mc) %>% 
    left_join(mc_private, by = c("d")) %>% 
    left_join(mc_private_ptc %>% rename(bid_ptc = bid), by = c("d")) %>% 
    select(d, starts_with("bid")) %>% 
    mutate(bid_nonwind = bid_nonwind + 5, bid_ptc = bid_ptc - 5) %>%  # shift lines for readability
    tidyr::gather("var", "value",-d) %>%
    mutate(policy = gregexpr("_ptc",text = var) > 0) %>%
    mutate(var = factor(var, levels = c("bid_nonwind", "bid", "bid_ptc"))) %>% 
    ggplot(aes(d, value, color = var, 
               linetype = factor(var, levels = c("bid", "bid_nonwind", "bid_ptc"))
               )) + geom_line(size = 1.5) +
    scale_color_manual(values=c("black","blue","red")) +
    annotate("text", x=505, y=155, label=expression(MC[nonwind]), hjust = 0, size = 5, parse = TRUE) +
    annotate("text", x=505, y=50, label="S", hjust = 0, size = 5, parse = TRUE) +
    annotate("text", x=505, y=20, label=expression(S[PTC]), hjust = 0, size = 5, parse = TRUE) +
    annotate("text", x=500, y=-100, label="Bid Quantities", hjust = 0, vjust = 1, size = 5) +
    geom_segment(aes(x = 100, y = -100, xend = 100, yend = 140), color = "grey25") +
    annotate("text", x=100, y=150, label="D[1]", size = 5, color = "grey25", parse = TRUE) +
    geom_segment(aes(x = 300, y = -100, xend = 300, yend = 140), color = "grey25") +
    annotate("text", x=300, y=150, label="D[2]", size = 5, color = "grey25", parse = TRUE) +
    geom_segment(aes(x = 400, y = -100, xend = 400, yend = 140), color = "grey25") +
    annotate("text", x=400, y=150, label="D[3]", size = 5, color = "grey25", parse = TRUE) +
    theme_bw() +
    theme(panel.border=element_rect(color="white")) +
    theme(legend.position = "none",
          axis.ticks.y =element_blank(),
          text = element_text(size = 16),
          axis.text=element_text(size=18)) + 
    scale_x_continuous(breaks = c(),
                       limits = c(NA, 600)) +
    scale_y_continuous(breaks = c(-subsidy-5, 0), # shift subsidy line to match for readability
                       minor_breaks = NULL,
                       labels = c(expression(MC[wind] - phi), expression(MC[wind]))) +
    geom_vline(xintercept = 0, size=.5) + # geom_hline(yintercept = 0, size=.5) +
    labs(x="", y="$") +
    theme(axis.title.y = element_text(angle = 0, vjust = 1)) )

# add brackets to label W and ΔA
bracketsGrob <- function(...){
  l <- list(...)
  e <- new.env()
  e$l <- l
  grid::recordGrob(  {
    do.call(grid.brackets, l)
  }, e)
}

b1 <- bracketsGrob(.5, 0.2, .2, 0.2, h=0.05, lwd=2, col="black")
b2 <- bracketsGrob(.575, 0.2, .5, 0.2, h=0.05, lwd=2, col="black")

(p <- p_bids + 
    annotation_custom(b1) +
    annotate("text", x=200, y=-80, label="W", size = 5, parse = TRUE) +
    annotation_custom(b2) +
    annotate("text", x=325, y=-80, label="Delta~A", size = 5, parse = TRUE))

ggsave(file.path(root,"output","figures", "dispatch.png"),
       width = 8, height = 4)


## PLOTS NET BENEFITS WITH DISPATCH-ONLY LINE FOR DISCUSSION ----------

plot_data <- wide_data %>%
    select(d, starts_with("soc_"),starts_with("net")) %>%
    tidyr::gather("var", "value",-d) %>%
    mutate(policy = case_when(
                        gregexpr("_di",text = var) > 0 ~ "PTC - dispatch",
                        gregexpr("_ptc",text = var) > 0 ~ "PTC",
                        gregexpr("_net",text = var) > 0 ~ "PTC",
                        TRUE ~ "Baseline"),
           md_case = case_when(
                        gregexpr("_mid",text = var) > 0 ~ "mid",
                        gregexpr("_hi",text = var) > 0 ~ "hi",
                        TRUE ~ "0"),
           net_cost = gregexpr("net",text = var) > 0) %>%
    filter(d <= 600) %>%
    group_by(var) %>% 
      mutate(dropid = rep(seq_len(n()/2), each = 20, length.out = n())) %>%
    ungroup() %>%
      filter(!(dropid%%2 == 0 &  policy == "PTC - dispatch" ))

ymin_mc = plot_data %>% filter(!net_cost) %>% select(value) %>% min()
ymax_mc = plot_data %>% filter(!net_cost) %>% select(value) %>% max()
ymin_tc = plot_data %>% filter(net_cost) %>% select(value) %>% min()
ymax_tc = plot_data %>% filter(net_cost) %>% select(value) %>% max()

facet_data <- plot_data %>%
    mutate(facet_group = 
             case_when(md_case == "0" ~ '1',
                       md_case == "mid" ~ '2',
                       TRUE ~ "3") )

md_names <- list(
  '1' = "md = 0",
  '2' = expression("0 < md <" ~ phi),
  '3' = expression(phi ~ "< md")
  )

md_labeller <- function(variable,value){
  return(md_names[value])
}


## just md = 0 and md high case  ---------------------------------------------------

plotsize = 1.5

policy_labs <- list(expression(S), expression(S[PTC]), expression(S[PTC] - "Dispatch Only"))
( p_mc2 <- facet_data %>%
    filter(!net_cost, md_case != "mid") %>%
    ggplot(.) +
    theme_cowplot() +
    geom_hline(yintercept = 0, size=.5) +
    geom_vline(xintercept = 0, size=.5) +
    geom_line(aes(x=d,y=value,
                  linetype=policy, color=policy), size = plotsize) + 
    scale_linetype_manual(values=c("solid","solid", "dotted"),
                       labels=policy_labs) +
    scale_color_manual(labels=policy_labs,
                       values=c("blue","red","red")) +
    coord_cartesian(ylim=c(ymin_mc,ymax_mc)) +
    theme(legend.position = c(.05,.8),
          text = element_text(size = 16),
          axis.text=element_text(size=14),
          axis.title.x = element_blank(),
          axis.ticks =element_blank(),
          axis.text.x=element_blank(),
          legend.title = element_blank(),
          legend.text = element_text(size=16)) + 
    labs(x="Demand",y="Social Marginal Costs") + 
    scale_y_continuous(breaks = c(-subsidy,0),
                       labels = c(expression(MC[wind] - phi), expression(MC[wind]))
                       ) +
    facet_wrap(facet_group  ~ ., labeller=md_labeller) )

policy_labs <- c("PTC","PTC - Dispatch Only")
( p_tc2 <- facet_data %>%
    filter(net_cost, md_case != "mid") %>%
    ggplot(.) +
    theme_cowplot() +
    geom_hline(yintercept = 0, size=.5) +
    geom_vline(xintercept = 0, size=.5) +
    geom_line(aes(x=d,y=value,
                  linetype=policy),size = plotsize) + 
    scale_linetype_manual(values=c("solid","dotted"),
                       labels= policy_labs) +
    coord_cartesian(ylim=c(ymin_tc,ymax_tc)) +
    theme(legend.position = c(.05,.8),
          legend.title = element_blank(),
          text = element_text(size = 16),
          legend.text = element_text(size=16),
          axis.text=element_text(size=14),
          axis.title.x = element_blank(),
          axis.ticks =element_blank(),
          axis.text.x=element_blank()) + 
    labs(x="Demand",y="Net Benefits") + 
    scale_y_continuous(breaks = c(0),
                   labels = c("              0")) + # hack to align gridded figures
    facet_wrap(facet_group  ~ ., labeller=md_labeller))

( figure_welfare <- grid.arrange(p_mc2,p_tc2, ncol=1) )

ggsave(file.path(root,"output","figures", "net_benefits.png"), 
        figure_welfare, width = 8, height = 5)
