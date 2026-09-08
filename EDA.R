# =========================================================
# EDA - Interrupciones de agua y alcantarillado (SUNASS)
# Fuente: datosabiertos.gob.pe
# Autor: Brayan Esteban Reza Smith
# =========================================================

library(tidyverse)
library(janitor)
library(lubridate)
library(scales)  # para formatear números en los ejes

# =========================================================
# 1. IMPORTACIÓN
# =========================================================
interrupciones <- read_csv("data/Interrupciones_Dataset.csv",
                           locale = locale(encoding = "UTF-8")) %>%
  clean_names()

glimpse(interrupciones)

# =========================================================
# 2. LIMPIEZA Y VARIABLES DERIVADAS
# =========================================================
interrupciones <- interrupciones %>%
  mutate(
    inicio_dt = ymd(fechainicio) + horainicio,
    fin_dt    = ymd(fechafin) + horafin,
    duracion_horas = as.numeric(difftime(fin_dt, inicio_dt, units = "hours")),
    mes = floor_date(ymd(fechainicio), "month")
  )

# Subset limpio solo para el análisis de duración (excluye duración <=0 y >7 días)
interrupciones_duracion <- interrupciones %>%
  filter(duracion_horas > 0, duracion_horas <= 24 * 7)

# =========================================================
# 3. ESTADÍSTICA DESCRIPTIVA
# =========================================================

## --- A. Variables numéricas ---------------------------------
resumen_numericas <- interrupciones %>%
  summarise(
    across(c(duracion_horas, numconexdom, unidadesuso),
           list(media = ~mean(.x, na.rm = TRUE),
                mediana = ~median(.x, na.rm = TRUE),
                sd = ~sd(.x, na.rm = TRUE),
                min = ~min(.x, na.rm = TRUE),
                max = ~max(.x, na.rm = TRUE)),
           .names = "{.col}_{.fn}")
  )
print(resumen_numericas, width = Inf)

# Duración (subset limpio, sin outliers)
summary(interrupciones_duracion$duracion_horas)
sd(interrupciones_duracion$duracion_horas, na.rm = TRUE)

## --- B. Tablas de frecuencia (variables categóricas) --------
tabla_tipointerrupcion <- interrupciones %>%
  count(tipointerrupcion) %>%
  mutate(pct = round(100 * n / sum(n), 1))
tabla_tipointerrupcion

tabla_tiposervicio <- interrupciones %>%
  count(tiposervicio) %>%
  mutate(pct = round(100 * n / sum(n), 1))
tabla_tiposervicio

tabla_motivo <- interrupciones %>%
  count(motivointerrupcion, sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  head(10)
tabla_motivo

tabla_departamento <- interrupciones %>%
  count(departamento, sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  head(10)
tabla_departamento

## --- C. Tablas cruzadas (relación entre variables) -----------
cruce_tipo_servicio <- interrupciones %>%
  count(tipointerrupcion, tiposervicio) %>%
  pivot_wider(names_from = tiposervicio, values_from = n, values_fill = 0)
cruce_tipo_servicio

cruce_tipo_departamento <- interrupciones %>%
  filter(departamento %in% tabla_departamento$departamento) %>%
  count(departamento, tipointerrupcion) %>%
  pivot_wider(names_from = tipointerrupcion, values_from = n, values_fill = 0) %>%
  mutate(pct_imprevista = round(100 * IMPREVISTA / (IMPREVISTA + PROGRAMADA), 1)) %>%
  arrange(desc(pct_imprevista))
cruce_tipo_departamento

cruce_motivo_tipo <- interrupciones %>%
  filter(motivointerrupcion %in% tabla_motivo$motivointerrupcion) %>%
  count(motivointerrupcion, tipointerrupcion) %>%
  pivot_wider(names_from = tipointerrupcion, values_from = n, values_fill = 0)
cruce_motivo_tipo

# Guardar datos limpios
write_csv(interrupciones, "data/interrupciones_limpio.csv")

# =========================================================
# 4. VISUALIZACIONES
# =========================================================

dir.create("figures", showWarnings = FALSE)

## --- Paleta y tema consistentes -------------------------------
colores_tipo <- c("IMPREVISTA" = "#D64550", "PROGRAMADA" = "#2A9D8F")

tema_propio <- theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "gray40", size = 11),
    plot.caption = element_text(color = "gray50", size = 8, hjust = 1),
    panel.grid.minor = element_blank()
  )

## --- Gráfico 1: Interrupciones por mes ------------------------
g1 <- interrupciones %>%
  count(mes) %>%
  ggplot(aes(x = mes, y = n)) +
  geom_line(color = "#1D3557", linewidth = 1) +
  geom_point(color = "#1D3557", size = 1.5) +
  scale_y_continuous(labels = comma) +
  labs(title = "Interrupciones del servicio registradas por mes",
       subtitle = "Agua potable y alcantarillado, empresas prestadoras reportadas a SUNASS",
       x = "Mes", y = "Número de interrupciones",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio
g1
ggsave("figures/01_interrupciones_por_mes.png", g1, width = 8, height = 5, dpi = 150)

## --- Gráfico 2: Top 10 EPS -------------------------------------
g2 <- interrupciones %>%
  count(eps, sort = TRUE) %>%
  head(10) %>%
  ggplot(aes(x = reorder(eps, n), y = n)) +
  geom_col(fill = "#F4A261") +
  geom_text(aes(label = comma(n)), hjust = -0.1, size = 3.3) +
  coord_flip() +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Top 10 EPS con más interrupciones registradas",
       subtitle = "Empresas prestadoras de servicio de saneamiento",
       x = NULL, y = "Número de interrupciones",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio
g2
ggsave("figures/02_top_eps.png", g2, width = 8, height = 5, dpi = 150)

## --- Gráfico 3: Imprevista vs Programada -----------------------
g3 <- tabla_tipointerrupcion %>%
  ggplot(aes(x = tipointerrupcion, y = n, fill = tipointerrupcion)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(comma(n), " (", pct, "%)")), vjust = -0.5, size = 3.8) +
  scale_fill_manual(values = colores_tipo) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Interrupciones imprevistas vs. programadas",
       subtitle = "Proporción del total de registros nacionales",
       x = NULL, y = "Número de interrupciones",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio +
  theme(legend.position = "none")
g3
ggsave("figures/03_imprevista_vs_programada.png", g3, width = 7, height = 5, dpi = 150)

## --- Gráfico 4: Duración según tipo ----------------------------
g4 <- interrupciones_duracion %>%
  ggplot(aes(x = tipointerrupcion, y = duracion_horas, fill = tipointerrupcion)) +
  geom_boxplot() +
  scale_fill_manual(values = colores_tipo) +
  labs(title = "Duración de interrupciones según tipo",
       subtitle = "Excluye registros con duración ≤ 0 h o > 7 días (posibles errores de registro)",
       x = NULL, y = "Duración (horas)",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio +
  theme(legend.position = "none")
g4
ggsave("figures/04_duracion_por_tipo.png", g4, width = 7, height = 5, dpi = 150)

## --- Gráfico 5: Por departamento (volumen total) ---------------
g5 <- interrupciones %>%
  count(departamento, sort = TRUE) %>%
  head(10) %>%
  ggplot(aes(x = reorder(departamento, n), y = n)) +
  geom_col(fill = "#2A9D8F") +
  geom_text(aes(label = comma(n)), hjust = -0.1, size = 3.3) +
  coord_flip() +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Top 10 departamentos con más interrupciones registradas",
       subtitle = "Distribución geográfica por volumen total",
       x = NULL, y = "Número de interrupciones",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio
g5
ggsave("figures/05_por_departamento.png", g5, width = 8, height = 5, dpi = 150)

## --- Gráfico 6: Principales motivos de interrupción ------------
g6 <- tabla_motivo %>%
  ggplot(aes(x = reorder(motivointerrupcion, n), y = n)) +
  geom_col(fill = "#E76F51") +
  geom_text(aes(label = comma(n)), hjust = -0.1, size = 3.3) +
  coord_flip() +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Top 10 motivos de interrupción del servicio",
       subtitle = "Causas más frecuentes reportadas por las EPS",
       x = NULL, y = "Número de interrupciones",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio
g6
ggsave("figures/06_principales_motivos.png", g6, width = 9, height = 5.5, dpi = 150)

## --- Gráfico 7: % de interrupciones imprevistas por departamento
g7 <- cruce_tipo_departamento %>%
  ggplot(aes(x = reorder(departamento, pct_imprevista), y = pct_imprevista)) +
  geom_col(fill = "#D64550") +
  geom_text(aes(label = paste0(pct_imprevista, "%")), hjust = -0.1, size = 3.3) +
  coord_flip() +
  scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 100)) +
  labs(title = "% de interrupciones imprevistas por departamento",
       subtitle = "Entre los 10 departamentos con más registros — a mayor %, menor cumplimiento de programación previa",
       x = NULL, y = "% imprevistas sobre el total del departamento",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio
g7
ggsave("figures/07_pct_imprevista_departamento.png", g7, width = 9, height = 5.5, dpi = 150)

## --- Gráfico 8: Motivo vs Tipo de interrupción ------------------
g8 <- cruce_motivo_tipo %>%
  pivot_longer(cols = c(IMPREVISTA, PROGRAMADA), names_to = "tipo", values_to = "n") %>%
  ggplot(aes(x = reorder(motivointerrupcion, n, sum), y = n, fill = tipo)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = colores_tipo) +
  coord_flip() +
  scale_y_continuous(labels = comma) +
  labs(title = "Principales motivos, según tipo de interrupción",
       subtitle = "Comparación imprevista vs. programada por causa",
       x = NULL, y = "Número de interrupciones", fill = "Tipo",
       caption = "Fuente: datosabiertos.gob.pe (SUNASS)") +
  tema_propio
g8
ggsave("figures/08_motivo_por_tipo.png", g8, width = 9, height = 6, dpi = 150)