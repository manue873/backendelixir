defmodule Backendelixir.Transit.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  @piura_min_lat -5.6000
  @piura_max_lat -4.8000
  @piura_min_lng -81.3500
  @piura_max_lng -80.0000

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :sequence,
             :latitude,
             :longitude,
             :route_id,
             :inserted_at,
             :updated_at
           ]}
  schema "stops" do
    field :name, :string
    field :sequence, :integer
    field :latitude, :float
    field :longitude, :float

    belongs_to :route, Backendelixir.Transit.Route

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [:name, :sequence, :latitude, :longitude, :route_id])
    |> validate_required([:name, :sequence, :route_id])
    |> validate_number(:sequence, greater_than: 0)
    |> validate_piura_bounds()
    |> foreign_key_constraint(:route_id)
  end

  defp validate_piura_bounds(changeset) do
    lat = get_field(changeset, :latitude)
    lng = get_field(changeset, :longitude)

    changeset
    |> validate_latitude(lat)
    |> validate_longitude(lng)
  end

  defp validate_latitude(changeset, nil), do: changeset

  defp validate_latitude(changeset, lat) when lat < @piura_min_lat or lat > @piura_max_lat do
    add_error(
      changeset,
      :latitude,
      "la latitud #{lat} está fuera de la jurisdicción operativa de Piura, Perú (rango permitido: #{@piura_min_lat} a #{@piura_max_lat})"
    )
  end

  defp validate_latitude(changeset, _lat), do: changeset

  defp validate_longitude(changeset, nil), do: changeset

  defp validate_longitude(changeset, lng) when lng < @piura_min_lng or lng > @piura_max_lng do
    add_error(
      changeset,
      :longitude,
      "la longitud #{lng} está fuera de la jurisdicción operativa de Piura, Perú (rango permitido: #{@piura_min_lng} a #{@piura_max_lng})"
    )
  end

  defp validate_longitude(changeset, _lng), do: changeset

  def piura_bounds do
    %{
      min_latitude: @piura_min_lat,
      max_latitude: @piura_max_lat,
      min_longitude: @piura_min_lng,
      max_longitude: @piura_max_lng
    }
  end
end
