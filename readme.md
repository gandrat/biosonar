# Estruturação de Banco de Dados Espacial para o Monitoramento de Mamíferos Marinhos em Levantamentos Sísmicos

Repositório contendo os scripts de estruturação de banco de dados geoespacial, limpeza de dados, análise de esforço e visualização de resultados para o Trabalho de Conclusão de Curso (TCC) do **Curso Técnico em Geoprocessamento** do **Instituto Federal do Rio Grande do Sul (IFRS)**.

## Sobre o Projeto

O avanço das fronteiras exploratórias offshore exige um monitoramento rigoroso para mitigar os impactos da aquisição sísmica sobre a fauna marinha. Este projeto propõe a estruturação de um banco de dados espacial corporativo integrado a ferramentas de Sistema de Informação Geográfica (SIG) para processar, armazenar e analisar dados de ocorrência de mamíferos marinhos, englobando tanto avistagens visuais quanto detecções acústicas (Monitoramento Acústico Passivo - PAM).

O grande diferencial analítico do projeto é a implementação de um cálculo de Esforço Amostral contínuo e a derivação de taxas de encontro espacializadas, permitindo a visualização precisa das áreas de maior densidade de animais em relação ao esforço empregado pelo navio sísmico.

## Metodologia e Fluxo de Trabalho

O processamento foi dividido em 4 etapas principais, automatizadas por meio de scripts em R e SQL:

### 1. Pré-processamento e Espacialização de Dados (R e pacote `sf`)
* **Limpeza Taxonômica e de Dados:** Importação de planilhas de avistagens, detecções e navegação (`.ods` e `.csv`), com padronização de tipos de dados (tempo e texto).
* **Espacialização de Ocorrências:** Transformação de coordenadas tabulares em geometrias do tipo ponto (`POINT`) utilizando o Sistema de Referência oficial **SIRGAS 2000 (EPSG:4674)**.
* **Geração de Trilhas de Navegação:** Conversão de milhares de pontos de GPS em linhas contínuas (`LINESTRING`) agrupadas por dia de operação, reconstruindo a trajetória exata da embarcação.
* **Malha Espacial (Grids):** Geração de grades regulares de 1 km e 10 km, filtradas espacialmente pelos limites da Amazônia Azul para excluir áreas terrestres.

### 2. Estruturação do Banco de Dados Relacional Espacial (PostgreSQL + PostGIS)
Os dados processados são ingeridos diretamente em um banco de dados PostGIS, estruturando o seguinte modelo lógico com integridade referencial:
* `taxon`: Tabela dimensional atuando como chave primária (`PK`).
* `sightings` e `detections`: Tabelas espaciais de pontos interligadas ao táxon por chave estrangeira (`FK`), garantindo que apenas espécies previamente cadastradas sejam inseridas.
* `navigation_points` e `navigation_tracks`: Histórico de navegação.
* Criação de Índices Espaciais (`GIST`) em todas as tabelas para otimização de consultas e renderização no SIG.

### 3. Modelagem de Esforço e Taxa de Encontro (SQL Avançado)
Toda a modelagem pesada ocorre dentro do banco de dados, utilizando funções nativas do PostGIS para máxima performance:
* **Cálculo de Esforço (Quilometragem):** Criação de uma tabela física (`grid_10km_effort`) que calcula o comprimento geodésico exato das trilhas de navegação que cruzam cada célula da grade. Utilizou-se o tipo geométrico `::geography` para garantir cálculos perfeitos de distância sobre o elipsoide (GRS80), sem distorções de projeção.
* **SPUE e DPUE:** Criação de uma Visão (`VIEW`) utilizando Common Table Expressions (CTEs) para cruzar a grade de esforço com os pontos de ocorrência, resultando em:
  * $SPUE = \frac{Total de Avistagens}{Esforço (km)}$ (Sightings Per Unit Effort)
  * $DPUE = \frac{Total de Deteccoes}{Esforço (km)}$ (Detections Per Unit Effort)

### 4. Análise Visual e Gráficos
Extração de dados agregados do banco via SQL diretamente para o R, utilizando o pacote `ggplot2` para elaboração de figuras em alta qualidade (300 dpi) destinadas ao documento acadêmico:
* Comparativo taxonômico do número de avistagens vs. detecções por Subordem/Família.
* Evolução temporal do esforço amostral diário (em quilômetros navegados).

## Estrutura de Arquivos

* `01_import_data.R`: Script para leitura dos registros biológicos, importação para o banco, definição de restrições (PKs/FKs) e geração da malha amostral (grids).
* `01_import_navigation_points.R`: Script para ingestão e conversão do log de navegação (pontos para linhas diárias).
* `02_figures.R`: Script voltado a análises estatísticas descritivas, conectando-se ao PostGIS e gerando os gráficos de esforço e composição taxonômica.
* `04_sql_esforco.sql`: Código em linguagem SQL executado no banco de dados para criar as tabelas e views analíticas que calculam o Esforço e as taxas SPUE/DPUE espacializadas.

## Tecnologias e Ferramentas

* **R (Tidyverse & sf):** Manipulação de dados, Geoprocessamento vetorial, integração com Banco de Dados e Data Visualization.
* **PostgreSQL + PostGIS:** Armazenamento robusto e operações espaciais de alto desempenho.
* **QGIS:** Software de mesa utilizado para o layout de mapas finais e validação das geometrias.

## Autoria

Trabalho desenvolvido por Anna Carolina Pinheiro Torma e orientado por Tiago Gandra no âmbito do **Curso Técnico em Geoprocessamento — IFRS**. Os dados utilizados e a demanda técnica de criação deste sistema de monitoramento foram gentilmente fornecidos pela empresa **BioSonar** ([https://www.biosonar.com.br/](https://www.biosonar.com.br/)).
tiago.gandra@riogrande.ifrs.edu.br