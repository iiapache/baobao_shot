from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    service_name: str = "caption-svc"
    http_port: int = 8007
    environment: str = "dev"


settings = Settings()
