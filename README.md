# Caminho Azul

O Caminho Azul é um aplicativo para acompanhar estudantes com TEA (Transtorno do
Espectro Autista). Ele liga a escola, a unidade de saúde (UBS) e a família.

Cada pessoa entra com a própria conta e vê só a parte que lhe cabe.

## Quem usa e o que faz

| Quem | O que faz no aplicativo |
|---|---|
| **Administração** | Cadastra as escolas e as UBS e cria as contas de todas as pessoas. |
| **Direção da escola** | Cadastra os estudantes, aprova os casos e encaminha para a UBS. |
| **Professor(a)** | Abre o caso do estudante e registra o que observa em sala. |
| **Direção da UBS** | Recebe os encaminhamentos e escolhe o(a) psicólogo(a) responsável. |
| **Psicólogo(a)** | Atende e registra a devolutiva para a escola e para a família. |
| **Família** | Acompanha o andamento, recebe avisos e lê as devolutivas. |

## Como começar

1. **Instale o aplicativo** no celular Android. O passo a passo está no
   [Guia de uso](docs/GUIA_DE_USO.md#1-instalar-no-celular).
2. **Entre como Administração** e prepare a rede: escolas, UBS e contas das
   pessoas. Veja o [Guia da Administração](docs/ADMINISTRACAO.md).
3. Cada pessoa cadastrada **recebe um e-mail** para criar a própria senha e já
   pode entrar.

## Documentação

| Documento | Para quem |
|---|---|
| [Guia de uso](docs/GUIA_DE_USO.md) | Todas as pessoas: instalar, entrar e usar cada perfil. |
| [Guia da Administração](docs/ADMINISTRACAO.md) | Quem administra: preparar a rede e cuidar das contas. |
| [Documentação técnica](docs/TECNICO.md) | Desenvolvedores: rodar o projeto, testar, gerar o APK e publicar. |
| [Modelo de dados](docs/MODELO_DADOS.md) | Desenvolvedores: como as informações ficam guardadas. |
| [Guia da marca](docs/identidade/GUIA_MARCA.md) | Quem for usar o logotipo e as cores. |

## Bom saber

- Os dados ficam no Google Firebase, no plano gratuito.
- As regras de segurança impedem que um perfil veja o que não é dele. Por
  exemplo, a família não vê as observações internas da escola.
- Hoje o aplicativo roda no **Android** e no **navegador**. Ainda não há versão
  para **iPhone**.
- Os avisos para a família aparecem **com o aplicativo aberto**. Avisos com o
  aplicativo fechado (push) exigiriam um serviço pago.
