// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_storage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingTicketAdapter extends TypeAdapter<PendingTicket> {
  @override
  final int typeId = 0;

  @override
  PendingTicket read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingTicket(
      transactionId: fields[0] as String,
      endpoint: fields[1] as String,
      timestamp: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PendingTicket obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.transactionId)
      ..writeByte(1)
      ..write(obj.endpoint)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingTicketAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
