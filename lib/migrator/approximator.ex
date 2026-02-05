defmodule Migrator.Approximator do

  #key_types = {:atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list}

  def promote(field_org) do
    promoter = fn left_org, promoter_fun ->
      promoter_fun = &promoter_fun.(&1, promoter_fun)
      case left_org do
        # {:union, {left_u, right_u}} -> {:union, {left_u |> promoter_fun.(), right_u |> promoter_fun.()}}

        #{:tuple, _} -> {:tuple, left_org}
        #{:open_map, _} -> {:open_map, left_org}
        :empty_list -> {:list, [left_org]}
        {:non_empty_list, _} -> {:list, [left_org]}
        {:gradual, :fun} -> {:fun, [left_org]}
        #{:fun, _} -> {:fun_top, [left_org]}
        {:interval, _} -> {:integer, [left_org]}
        #{:atom, _} -> {:atom, [left_org]}

        _ -> {left_org, [left_org]}
      end
    end
    field_org |> Enum.map(fn {left_f, right_f} -> {left_f |> promoter.(promoter), right_f} end)
  end

  def map(fields) do

    merging = fn {list1, field_m}, merging_fun ->
        merging_fun = &merging_fun.(&1, merging_fun)
        case list1 do
          [] -> {field_m, []}
          [field_l1 | rest_l1] ->
            {field_m_new, rest_l1_new} = {rest_l1, field_m} |> merging_fun.()
            if field_m_new == nil do
              {nil, [field_l1 | rest_l1_new]}
            else
              {{left_l1, left_l1_org}, right_l1} = field_l1
              {{left_m, left_m_org}, right_m} = field_m_new
              # If K^s' in L_1
              key_type_found_in_list? = left_l1 == left_m
              # If atom^s' in L_1
              atom_type_found_in_list? = left_l1 == :atom
              # If K uinon s is a subtype of K union s'
              {left_m_org_new, merging_org_type_subtype?} = if key_type_found_in_list?, do: {left_l1, {left_m_org, left_l1_org}} |> merge_subtypes(), else: {left_m_org, false}
              {left_m_org_new, merging_org_type_subtype?}
              cond do
                key_type_found_in_list? and merging_org_type_subtype? -> {nil, [field_l1 | rest_l1_new]}
                key_type_found_in_list? and !merging_org_type_subtype? -> {{{left_m, left_m_org_new}, (right_l1 ++ right_m) |> Enum.uniq()}, rest_l1_new}
                !key_type_found_in_list? and atom_type_found_in_list? and merging_org_type_subtype? -> {nil, [field_l1 | rest_l1_new]}
                !key_type_found_in_list? and atom_type_found_in_list? and !merging_org_type_subtype? -> {field_m_new, [field_l1 | rest_l1_new]}
                !key_type_found_in_list? and !atom_type_found_in_list? and !merging_org_type_subtype? -> {field_m_new, [field_l1 | rest_l1_new]}
              end
            end
        end
      end

    check_if_set = fn fields -> fields |> Enum.map(fn {left_f, right_f} ->
          right_f_new = right_f |> Enum.reduce({}, fn type, acc -> if acc == {}, do: {type}, else: {:union, {type, acc |> elem(0)}} end)
          right_f_new = case left_f do
            {:atom, [atom: _]} -> right_f_new
            _ -> {:if_set, right_f_new}
          end
          {left_f, right_f_new}
        end)
      end

    total_merging = fn fields ->
      fields |> Enum.reduce([], fn field, list1 ->
          {field_new, list_l1_new} = {list1, field} |> merging.(merging)
          if field_new == nil do
            list_l1_new
          else
            [field_new | list_l1_new]
          end
        end)|> check_if_set.()
    end

    fields |> total_merging.() |> remove_extra_information()
  end

  #key_types = {:atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list}
  defp merge_subtypes({:integer, {left_m_org, left_l1_org}}) do
    comparing_intervals = fn {{n1_m, n2_m}, {n1_l1, n2_l1}} ->
        if Range.disjoint?(n1_m..n2_m, n1_l1..n2_l1) do
          cond do
            n2_m + 1 == n1_l1 -> {[{:interval, {n1_m, n2_l1}}], false}
            n2_l1 + 1 == n1_m -> {[{:interval, {n1_l1, n2_m}}], false}
            true -> {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
          end
        else
          subtype? = n1_m..n2_m |> Enum.to_list() |> Enum.reduce(true, fn n, acc -> acc and Enum.member?(n1_l1..n2_l1, n) end)
          if subtype? do
            {[{:interval, {n1_l1, n2_l1}}], true}
          else
            cond do
              n1_m <= n1_l1 and n2_m <= n2_l1 -> {[{:interval, {n1_m, n2_l1}}], false}
              n1_m <= n1_l1 and n2_m >= n2_l1 -> {[{:interval, {n1_m, n2_m}}], false}
              n1_m >= n1_l1 and n2_m <= n2_l1 -> {[{:interval, {n1_l1, n2_l1}}], false}
              n1_m >= n1_l1 and n2_m >= n2_l1 -> {[{:interval, {n1_l1, n2_m}}], false}
            end
          end
        end
      end

    {{m_org_new, l1_org_new}, subtype_new?} = left_m_org |> Enum.reduce({{[], left_l1_org}, true}, fn lmo, {{acc_m_org, acc_l1_org}, acc_subtype?} ->
        acc_l1_org |> Enum.reduce({{acc_m_org, []}, acc_subtype?}, fn ll1o, {{acc_m_org_new, acc_l1_org_new}, acc_subtype_new?} ->
          case {lmo, ll1o} do
            # {:integer, :integer} -> {:integer, false} # keep both right-hand type?
            {:integer, _} -> {{[:integer], []}, false}
            {_, :integer} -> {{[], [nil]}, true}
            {{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}} ->
              {org_type, subtype?} = {{n1_m, n2_m}, {n1_l1, n2_l1}} |> comparing_intervals.()
              case org_type do
                [org_type_m, org_type_l1] -> {{acc_m_org_new ++ [org_type_m], acc_l1_org_new ++ [org_type_l1]}, acc_subtype_new? and subtype?}
                [org_type_union] -> {{acc_m_org_new, acc_l1_org_new ++ [org_type_union]}, acc_subtype_new? and subtype?}
              end
          end
        end)
      end)
    org_type_new = m_org_new ++ l1_org_new
    {org_type_new, subtype_new?}
  end
  defp merge_subtypes({:list, {left_m_org, left_l1_org}}) do
    # :empty_list -> {:list, [left_org]}
    # {:non_empty_list, _} -> {:list, [left_org]}
  end
  defp merge_subtypes({:fun_top, {left_m_org, left_l1_org}}) do
    # {:gradual, :fun} -> {:fun, [left_org]}
    # {:fun, _} -> {:fun_top, [left_org]}
  end
  defp merge_subtypes({_, {left_m_org, left_l1_org}}), do: (if left_m_org == left_l1_org, do: {left_m_org, true}, else: {left_m_org ++ left_l1_org, false})

  defp remove_extra_information(fields) do
    fields |> Enum.map(fn {{key_type, _}, right_f} -> {key_type, right_f} end)
  end
end
