

resource "pinecone_index" "test" {
  name      = var.INDEX_NAME
  dimension = 384
  spec = {
    serverless = {
      cloud  = "aws"
      region = "us-east-1"
    }
  }
}